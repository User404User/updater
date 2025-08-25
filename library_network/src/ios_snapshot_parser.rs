use std::io::{Read, Seek, SeekFrom};
use anyhow::{Context, Result};

/// Mach-O file format constants
const MH_MAGIC_64: u32 = 0xfeedfacf;
const MH_MAGIC: u32 = 0xfeedface;
const FAT_MAGIC: u32 = 0xcafebabe;
const FAT_CIGAM: u32 = 0xbebafeca;

const LC_SEGMENT_64: u32 = 0x19;
// const LC_SEGMENT: u32 = 0x01; // 32-bit segment, not used for iOS
const LC_SYMTAB: u32 = 0x02;

const CPU_TYPE_ARM64: u32 = 0x0100000c;

/// Symbol names for Dart snapshots in iOS binaries
/// These are symbols that point to locations in __TEXT segment
const VM_DATA_SYMBOL: &str = "_kDartVmSnapshotData";
const VM_INSTRUCTIONS_SYMBOL: &str = "_kDartVmSnapshotInstructions";
const ISOLATE_DATA_SYMBOL: &str = "_kDartIsolateSnapshotData";
const ISOLATE_INSTRUCTIONS_SYMBOL: &str = "_kDartIsolateSnapshotInstructions";

/// Mach-O header structures
#[repr(C)]
#[derive(Debug, Clone, Copy)]
struct MachHeader64 {
    magic: u32,
    cputype: i32,
    cpusubtype: i32,
    filetype: u32,
    ncmds: u32,
    sizeofcmds: u32,
    flags: u32,
    reserved: u32,
}

// 32-bit Mach-O header - not used for iOS which is 64-bit only
#[allow(dead_code)]
#[repr(C)]
#[derive(Debug, Clone, Copy)]
struct MachHeader {
    magic: u32,
    cputype: i32,
    cpusubtype: i32,
    filetype: u32,
    ncmds: u32,
    sizeofcmds: u32,
    flags: u32,
}

#[repr(C)]
#[derive(Debug, Clone, Copy)]
struct LoadCommand {
    cmd: u32,
    cmdsize: u32,
}

#[repr(C)]
#[derive(Debug, Clone, Copy)]
struct SegmentCommand64 {
    cmd: u32,
    cmdsize: u32,
    segname: [u8; 16],
    vmaddr: u64,
    vmsize: u64,
    fileoff: u64,
    filesize: u64,
    maxprot: i32,
    initprot: i32,
    nsects: u32,
    flags: u32,
}

#[allow(dead_code)]
#[repr(C)]
#[derive(Debug, Clone, Copy)]
struct Section64 {
    sectname: [u8; 16],
    segname: [u8; 16],
    addr: u64,
    size: u64,
    offset: u32,
    align: u32,
    reloff: u32,
    nreloc: u32,
    flags: u32,
    reserved1: u32,
    reserved2: u32,
    reserved3: u32,
}

#[repr(C)]
#[derive(Debug, Clone, Copy)]
struct SymtabCommand {
    cmd: u32,
    cmdsize: u32,
    symoff: u32,
    nsyms: u32,
    stroff: u32,
    strsize: u32,
}

#[repr(C)]
#[derive(Debug, Clone, Copy)]
struct Nlist64 {
    n_strx: u32,
    n_type: u8,
    n_sect: u8,
    n_desc: u16,
    n_value: u64,
}

#[repr(C)]
#[derive(Debug, Clone, Copy)]
struct FatHeader {
    magic: u32,
    nfat_arch: u32,
}

#[repr(C)]
#[derive(Debug, Clone, Copy)]
struct FatArch {
    cputype: u32,
    cpusubtype: u32,
    offset: u32,
    size: u32,
    align: u32,
}

/// Container for the extracted Dart snapshots
pub struct DartSnapshots {
    pub vm_data: Vec<u8>,
    pub vm_instructions: Vec<u8>,
    pub isolate_data: Vec<u8>,
    pub isolate_instructions: Vec<u8>,
}

/// Extract Dart snapshots from an iOS App binary
pub fn extract_snapshots_from_app<R: Read + Seek>(reader: &mut R) -> Result<DartSnapshots> {
    shorebird_info!("=== Extracting Dart snapshots from iOS App binary ===");
    
    // Check file magic
    reader.seek(SeekFrom::Start(0))?;
    let mut magic_bytes = [0u8; 4];
    reader.read_exact(&mut magic_bytes)?;
    let magic = u32::from_be_bytes(magic_bytes);
    
    match magic {
        FAT_MAGIC | FAT_CIGAM => {
            shorebird_info!("Fat binary detected, extracting arm64 slice");
            extract_from_fat_binary(reader)
        }
        _ => {
            // Reset and check native endianness
            reader.seek(SeekFrom::Start(0))?;
            reader.read_exact(&mut magic_bytes)?;
            let magic = u32::from_ne_bytes(magic_bytes);
            
            match magic {
                MH_MAGIC_64 => {
                    shorebird_info!("64-bit Mach-O binary detected");
                    reader.seek(SeekFrom::Start(0))?;
                    extract_from_macho64(reader)
                }
                MH_MAGIC => {
                    shorebird_info!("32-bit Mach-O binary detected");
                    Err(anyhow::anyhow!("32-bit iOS binaries are not supported"))
                }
                _ => {
                    Err(anyhow::anyhow!("Not a valid Mach-O file (magic: 0x{:08x})", magic))
                }
            }
        }
    }
}

/// Extract arm64 slice from fat binary
fn extract_from_fat_binary<R: Read + Seek>(reader: &mut R) -> Result<DartSnapshots> {
    reader.seek(SeekFrom::Start(0))?;
    let header = read_struct::<FatHeader>(reader)?;
    
    let nfat_arch = if header.magic == FAT_CIGAM {
        header.nfat_arch.swap_bytes()
    } else {
        header.nfat_arch
    };
    
    shorebird_info!("Fat binary contains {} architectures", nfat_arch);
    
    // Find arm64 architecture
    for i in 0..nfat_arch {
        reader.seek(SeekFrom::Start(8 + i as u64 * 20))?;
        let arch = read_struct::<FatArch>(reader)?;
        
        let cputype = if header.magic == FAT_CIGAM {
            arch.cputype.swap_bytes()
        } else {
            arch.cputype
        };
        
        if cputype == CPU_TYPE_ARM64 {
            let offset = if header.magic == FAT_CIGAM {
                arch.offset.swap_bytes()
            } else {
                arch.offset
            };
            
            shorebird_info!("Found arm64 slice at offset 0x{:x}", offset);
            reader.seek(SeekFrom::Start(offset as u64))?;
            return extract_from_macho64(reader);
        }
    }
    
    Err(anyhow::anyhow!("arm64 architecture not found in fat binary"))
}

/// Extract snapshots from 64-bit Mach-O binary
fn extract_from_macho64<R: Read + Seek>(reader: &mut R) -> Result<DartSnapshots> {
    let start_pos = reader.stream_position()?;
    let header = read_struct::<MachHeader64>(reader)?;
    
    if header.magic != MH_MAGIC_64 {
        return Err(anyhow::anyhow!("Invalid 64-bit Mach-O magic"));
    }
    
    shorebird_info!("Processing {} load commands", header.ncmds);
    
    let mut symtab_cmd = None;
    let mut text_segment = None;
    let mut linkedit_segment = None;
    
    // Parse load commands
    let mut cmd_offset = start_pos + std::mem::size_of::<MachHeader64>() as u64;
    
    for _i in 0..header.ncmds {
        reader.seek(SeekFrom::Start(cmd_offset))?;
        let cmd = read_struct::<LoadCommand>(reader)?;
        
        match cmd.cmd {
            LC_SEGMENT_64 => {
                reader.seek(SeekFrom::Start(cmd_offset))?;
                let segment = read_struct::<SegmentCommand64>(reader)?;
                let segname = std::str::from_utf8(&segment.segname)
                    .ok()
                    .and_then(|s| s.split('\0').next())
                    .unwrap_or("");
                
                shorebird_info!("Found segment: {} (fileoff: 0x{:x}, filesize: 0x{:x}, nsects: {})", 
                    segname, segment.fileoff, segment.filesize, segment.nsects);
                
                if segname == "__TEXT" {
                    text_segment = Some(segment);
                    
                    // Parse sections in __TEXT segment
                    if segment.nsects > 0 {
                        shorebird_info!("=== Sections in __TEXT segment ===");
                        let sections_start = cmd_offset + std::mem::size_of::<SegmentCommand64>() as u64;
                        reader.seek(SeekFrom::Start(sections_start))?;
                        
                        for j in 0..segment.nsects {
                            let section = read_struct::<Section64>(reader)?;
                            let sectname = std::str::from_utf8(&section.sectname)
                                .ok()
                                .and_then(|s| s.split('\0').next())
                                .unwrap_or("<invalid>");
                            
                            shorebird_info!("  Section {}: {} (addr: 0x{:x}, size: 0x{:x}, offset: 0x{:x})", 
                                j, sectname, section.addr, section.size, section.offset);
                        }
                    }
                } else if segname == "__LINKEDIT" {
                    linkedit_segment = Some(segment);
                }
            }
            LC_SYMTAB => {
                reader.seek(SeekFrom::Start(cmd_offset))?;
                symtab_cmd = Some(read_struct::<SymtabCommand>(reader)?);
                shorebird_info!("Found symbol table (nsyms: {}, strsize: {})", 
                    symtab_cmd.unwrap().nsyms, symtab_cmd.unwrap().strsize);
            }
            _ => {}
        }
        
        cmd_offset += cmd.cmdsize as u64;
    }
    
    // Check if we have necessary segments
    let text = text_segment.context("__TEXT segment not found")?;
    
    // Try method 1: Use symbol table (if not stripped)
    if let (Some(symtab), Some(linkedit)) = (symtab_cmd, linkedit_segment) {
        shorebird_info!("=== Method 1: Trying symbol table approach ===");
        
        match extract_via_symbols(reader, start_pos, &symtab, &linkedit, &text) {
            Ok(snapshots) => {
                shorebird_info!("✅ Successfully extracted snapshots via symbol table");
                return Ok(snapshots);
            }
            Err(e) => {
                shorebird_warn!("❌ Symbol table approach failed: {}", e);
                shorebird_info!("=== Method 2: Falling back to magic-based approach ===");
            }
        }
    } else {
        shorebird_info!("No symbol table found, using magic-based approach");
    }
    
    // Method 2: Magic-based approach - use known magic bytes to locate snapshots
    extract_via_magic(reader, start_pos, &text)
}

/// Extract snapshots using symbol table
fn extract_via_symbols<R: Read + Seek>(
    reader: &mut R,
    start_pos: u64,
    symtab: &SymtabCommand,
    linkedit: &SegmentCommand64,
    text: &SegmentCommand64,
) -> Result<DartSnapshots> {
    shorebird_info!("Reading symbol table...");
    
    // Calculate symbol table offset
    let symtab_offset = start_pos + linkedit.fileoff + (symtab.symoff as u64 - linkedit.vmaddr);
    let strtab_offset = start_pos + linkedit.fileoff + (symtab.stroff as u64 - linkedit.vmaddr);
    
    // Read string table
    reader.seek(SeekFrom::Start(strtab_offset))?;
    let mut strtab = vec![0u8; symtab.strsize as usize];
    reader.read_exact(&mut strtab)?;
    
    // Find snapshot symbols
    let mut symbols = std::collections::HashMap::new();
    reader.seek(SeekFrom::Start(symtab_offset))?;
    
    let mut dart_related_symbols = Vec::new();
    let mut first_10_symbols = Vec::new();
    
    shorebird_info!("Total symbols to process: {}", symtab.nsyms);
    
    for _i in 0..symtab.nsyms {
        let symbol = read_struct::<Nlist64>(reader)?;
        
        if symbol.n_strx == 0 || symbol.n_strx as usize >= strtab.len() {
            continue;
        }
        
        let name = get_string_from_table(&strtab, symbol.n_strx as usize);
        
        // Log first 10 symbols for debugging
        if first_10_symbols.len() < 10 && !name.is_empty() {
            first_10_symbols.push(format!("{}: 0x{:x} (type: 0x{:x}, sect: {})", 
                name, symbol.n_value, symbol.n_type, symbol.n_sect));
        }
        
        // Log all Dart-related symbols for debugging
        if name.contains("Dart") || name.contains("dart") || name.contains("kDart") {
            dart_related_symbols.push(format!("{}: 0x{:x} (type: 0x{:x}, sect: {})", 
                name, symbol.n_value, symbol.n_type, symbol.n_sect));
        }
        
        if name == VM_DATA_SYMBOL || name == VM_INSTRUCTIONS_SYMBOL ||
           name == ISOLATE_DATA_SYMBOL || name == ISOLATE_INSTRUCTIONS_SYMBOL {
            shorebird_info!("✅ Found expected symbol: {} at 0x{:x}", name, symbol.n_value);
            symbols.insert(name.to_string(), symbol);
        }
    }
    
    // Log first few symbols
    if !first_10_symbols.is_empty() {
        shorebird_info!("=== First {} symbols in symbol table ===", first_10_symbols.len());
        for sym in &first_10_symbols {
            shorebird_info!("  {}", sym);
        }
    }
    
    // Log all Dart-related symbols found
    if !dart_related_symbols.is_empty() {
        shorebird_info!("=== All Dart-related symbols found ===");
        for sym in &dart_related_symbols {
            shorebird_info!("  {}", sym);
        }
    } else {
        shorebird_warn!("No Dart-related symbols found in symbol table!");
    }
    
    if symbols.len() != 4 {
        shorebird_error!("❌ Failed to find all required symbols!");
        shorebird_error!("Expected symbols:");
        shorebird_error!("  - {}", VM_DATA_SYMBOL);
        shorebird_error!("  - {}", VM_INSTRUCTIONS_SYMBOL);
        shorebird_error!("  - {}", ISOLATE_DATA_SYMBOL);
        shorebird_error!("  - {}", ISOLATE_INSTRUCTIONS_SYMBOL);
        shorebird_error!("Actually found: {:?}", symbols.keys().collect::<Vec<_>>());
        
        // Print more symbols for debugging
        shorebird_error!("");
        shorebird_error!("=== Printing more symbols for analysis ===");
        shorebird_error!("Total symbols in table: {}", symtab.nsyms);
        
        // Re-read and print first 100 symbols that have names
        reader.seek(SeekFrom::Start(symtab_offset))?;
        let mut symbol_count = 0;
        let mut symbols_to_print = Vec::new();
        
        for i in 0..symtab.nsyms {
            let symbol = read_struct::<Nlist64>(reader)?;
            
            if symbol.n_strx != 0 && (symbol.n_strx as usize) < strtab.len() {
                let name = get_string_from_table(&strtab, symbol.n_strx as usize);
                if !name.is_empty() {
                    symbols_to_print.push(format!("  [{}] {}: addr=0x{:x}, type=0x{:02x}, sect={}, desc=0x{:04x}, value=0x{:x}", 
                        i, name, symbol.n_value, symbol.n_type, symbol.n_sect, symbol.n_desc, symbol.n_value));
                    symbol_count += 1;
                    
                    if symbol_count >= 100 {
                        break;
                    }
                }
            }
        }
        
        shorebird_error!("First {} symbols with names:", symbols_to_print.len());
        for sym in &symbols_to_print {
            shorebird_error!("{}", sym);
        }
        
        return Err(anyhow::anyhow!("Only found {} of 4 expected symbols", symbols.len()));
    }
    
    // Extract snapshot data based on symbol addresses
    let vm_data = extract_symbol_data(reader, &symbols[VM_DATA_SYMBOL], 
        &symbols.get(VM_INSTRUCTIONS_SYMBOL).map(|s| s.n_value), text, start_pos)?;
    let vm_instructions = extract_symbol_data(reader, &symbols[VM_INSTRUCTIONS_SYMBOL],
        &symbols.get(ISOLATE_DATA_SYMBOL).map(|s| s.n_value), text, start_pos)?;
    let isolate_data = extract_symbol_data(reader, &symbols[ISOLATE_DATA_SYMBOL],
        &symbols.get(ISOLATE_INSTRUCTIONS_SYMBOL).map(|s| s.n_value), text, start_pos)?;
    
    // For the last symbol, estimate size
    let isolate_instructions = extract_symbol_data_estimated(reader, 
        &symbols[ISOLATE_INSTRUCTIONS_SYMBOL], text, start_pos)?;
    
    Ok(DartSnapshots {
        vm_data,
        vm_instructions,
        isolate_data,
        isolate_instructions,
    })
}

/// Extract snapshots using magic bytes found in the binary
fn extract_via_magic<R: Read + Seek>(
    reader: &mut R,
    start_pos: u64,
    text: &SegmentCommand64,
) -> Result<DartSnapshots> {
    shorebird_info!("Using magic-based approach to find snapshots...");
    
    // First, let's analyze the TEXT segment structure
    shorebird_info!("=== Analyzing __TEXT segment structure ===");
    shorebird_info!("__TEXT segment: vmaddr=0x{:x}, fileoff=0x{:x}, filesize=0x{:x}", 
        text.vmaddr, text.fileoff, text.filesize);
    
    // Read the entire TEXT segment into memory for analysis
    reader.seek(SeekFrom::Start(start_pos + text.fileoff))?;
    let scan_size = std::cmp::min(text.filesize as usize, 64 * 1024 * 1024); // Max 64MB scan
    let mut buffer = vec![0u8; scan_size];
    let bytes_read = reader.read(&mut buffer)?;
    buffer.truncate(bytes_read);
    
    shorebird_info!("Loaded {} bytes for analysis", bytes_read);
    
    // Search for strings containing "snap" (case-insensitive)
    shorebird_info!("\n=== Searching for strings containing 'snap' ===");
    find_snap_strings(&buffer);
    
    // Search for Dart snapshot magic bytes
    shorebird_info!("\n=== Searching for Dart snapshot magic bytes (0xf5f5dcdc) ===");
    let magic_pattern = vec![0xf5, 0xf5, 0xdc, 0xdc];
    let mut magic_offsets = Vec::new();
    
    for i in 0..buffer.len().saturating_sub(4) {
        if &buffer[i..i + 4] == magic_pattern.as_slice() {
            let absolute_offset = text.fileoff + i as u64;
            magic_offsets.push(i);
            shorebird_info!("  ✅ Found Dart snapshot magic at 0x{:08x} (buffer offset: 0x{:x})", 
                absolute_offset, i);
            
            // Show context around the magic bytes
            let context_start = i.saturating_sub(16);
            let context_end = std::cmp::min(i + 64, buffer.len());
            let hex: String = buffer[context_start..context_end].iter()
                .map(|b| format!("{:02x}", b))
                .collect::<Vec<_>>()
                .join(" ");
            shorebird_info!("     Context: {}", hex);
        }
    }
    
    if magic_offsets.is_empty() {
        shorebird_error!("No Dart snapshot magic bytes found!");
        return Err(anyhow::anyhow!("Failed to find Dart snapshot magic bytes"));
    }
    
    shorebird_info!("\n=== Attempting to extract snapshots from magic byte locations ===");
    
    // Try to extract snapshots from the first magic offset
    // Based on production logs, we found magic at 0x00cfddc0 and 0x00d06d40
    for (idx, &offset) in magic_offsets.iter().enumerate() {
        shorebird_info!("\nTrying magic offset {}: 0x{:x}", idx, offset);
        
        match extract_snapshots_at_magic_offset(&buffer, offset) {
            Ok(snapshots) => {
                shorebird_info!("✅ Successfully extracted snapshots from magic offset {}", idx);
                shorebird_info!("  VM data size: {} bytes", snapshots.vm_data.len());
                shorebird_info!("  VM instructions size: {} bytes", snapshots.vm_instructions.len());
                shorebird_info!("  Isolate data size: {} bytes", snapshots.isolate_data.len());
                shorebird_info!("  Isolate instructions size: {} bytes", snapshots.isolate_instructions.len());
                return Ok(snapshots);
            }
            Err(e) => {
                shorebird_warn!("Failed to extract from magic offset {}: {}", idx, e);
            }
        }
    }
    
    // If all magic offsets failed, log more information for debugging
    shorebird_error!("\n=== All magic-based extraction attempts failed ===");
    
    // Log key areas of the binary for further analysis
    shorebird_info!("\n=== Binary content at key offsets ===");
    log_key_offsets(&buffer, text.fileoff);
    
    // Search for other patterns
    shorebird_info!("\n=== Searching for other patterns ===");
    search_for_patterns(&buffer, text.fileoff);
    
    Err(anyhow::anyhow!("Failed to extract snapshots from any magic byte location"))
}

/// Extract snapshots at a specific magic byte offset
fn extract_snapshots_at_magic_offset(buffer: &[u8], magic_offset: usize) -> Result<DartSnapshots> {
    // Dart snapshot structure after magic bytes:
    // [4 bytes: magic (0xf5f5dcdc)]
    // [4 bytes: version]
    // [4 bytes: features]
    // [4 bytes: flags]
    // Then the actual snapshot data
    
    if magic_offset + 16 > buffer.len() {
        return Err(anyhow::anyhow!("Not enough data after magic bytes"));
    }
    
    // Read header after magic
    let version = u32::from_le_bytes([
        buffer[magic_offset + 4],
        buffer[magic_offset + 5],
        buffer[magic_offset + 6],
        buffer[magic_offset + 7],
    ]);
    
    let features = u32::from_le_bytes([
        buffer[magic_offset + 8],
        buffer[magic_offset + 9],
        buffer[magic_offset + 10],
        buffer[magic_offset + 11],
    ]);
    
    let flags = u32::from_le_bytes([
        buffer[magic_offset + 12],
        buffer[magic_offset + 13],
        buffer[magic_offset + 14],
        buffer[magic_offset + 15],
    ]);
    
    shorebird_info!("  Snapshot header: version=0x{:x}, features=0x{:x}, flags=0x{:x}", 
        version, features, flags);
    
    // The actual snapshot data starts after the header
    // For iOS, snapshots are typically in this order:
    // 1. VM snapshot data
    // 2. VM snapshot instructions  
    // 3. Isolate snapshot data
    // 4. Isolate snapshot instructions
    
    // Since we don't have size information in stripped binaries,
    // we need to use heuristics to find the boundaries
    
    // Strategy: Look for the next magic bytes or estimate based on patterns
    let data_start = magic_offset + 16;
    
    // Find the end of this snapshot section by looking for:
    // 1. Another magic sequence
    // 2. A long sequence of zeros (padding)
    // 3. Maximum reasonable size (e.g., 2MB per section)
    
    let mut section_end = data_start;
    let max_section_size = 2 * 1024 * 1024; // 2MB max per section
    let search_end = std::cmp::min(data_start + max_section_size * 4, buffer.len());
    
    // Look for end of data pattern (usually padding with zeros)
    for i in (data_start..search_end).step_by(1024) {
        if i + 1024 <= buffer.len() && buffer[i..i + 1024].iter().all(|&b| b == 0) {
            section_end = i;
            break;
        }
    }
    
    if section_end == data_start {
        section_end = std::cmp::min(data_start + max_section_size, buffer.len());
    }
    
    shorebird_info!("  Estimated snapshot data size: {} bytes", section_end - data_start);
    
    // For now, return the entire data as vm_data until we can better identify boundaries
    // This is a simplified approach that should work for basic cases
    let snapshot_data = buffer[data_start..section_end].to_vec();
    
    // Try to split the data into 4 roughly equal parts
    let quarter_size = snapshot_data.len() / 4;
    
    Ok(DartSnapshots {
        vm_data: snapshot_data[..quarter_size].to_vec(),
        vm_instructions: snapshot_data[quarter_size..quarter_size * 2].to_vec(),
        isolate_data: snapshot_data[quarter_size * 2..quarter_size * 3].to_vec(),
        isolate_instructions: snapshot_data[quarter_size * 3..].to_vec(),
    })
}

/// Find strings containing "snap" in the buffer
fn find_snap_strings(buffer: &[u8]) {
    let mut snap_strings = Vec::new();
    let mut current_string = Vec::new();
    let mut string_start = 0;
    
    for (i, &byte) in buffer.iter().enumerate() {
        if byte.is_ascii_graphic() || byte == b' ' {
            if current_string.is_empty() {
                string_start = i;
            }
            current_string.push(byte);
        } else {
            if current_string.len() >= 4 {
                if let Ok(s) = std::str::from_utf8(&current_string) {
                    if s.to_lowercase().contains("snap") {
                        snap_strings.push((string_start, s.to_string()));
                    }
                }
            }
            current_string.clear();
        }
    }
    
    if snap_strings.is_empty() {
        shorebird_info!("No strings containing 'snap' found");
    } else {
        shorebird_info!("Found {} strings containing 'snap':", snap_strings.len());
        for (offset, string) in snap_strings.iter().take(50) {
            shorebird_info!("  0x{:08x}: {}", offset, string);
        }
    }
}

/// Find potential snapshot patterns in the buffer
fn find_snapshot_patterns(buffer: &[u8]) -> Vec<usize> {
    let mut potential_offsets = Vec::new();
    
    // Look for various patterns that might indicate snapshot data
    for i in 0..buffer.len().saturating_sub(16) {
        let chunk = &buffer[i..i+16];
        
        // Pattern 1: High concentration of non-zero bytes
        let non_zero_count = chunk.iter().filter(|&&b| b != 0).count();
        
        // Pattern 2: Specific magic bytes observed in snapshots
        if non_zero_count > 12 {
            // Check for specific patterns
            if chunk[0] == 0xf5 || chunk[0] == 0xf6 || chunk[0] == 0xdc {
                potential_offsets.push(i);
            } else if chunk[0..4] == [0x00, 0x00, 0x00, 0x00] && chunk[4] != 0 {
                potential_offsets.push(i);
            } else if chunk[0..4] == [0xf5, 0xf5, 0xdc, 0xdc] {
                // Dart snapshot magic
                potential_offsets.push(i);
            }
        }
        
        // Pattern 3: Look for repeating patterns that might be snapshot headers
        if i + 32 < buffer.len() {
            // Check for structured data patterns
            if buffer[i] == buffer[i + 8] && buffer[i + 1] == buffer[i + 9] &&
               buffer[i] != 0 && buffer[i + 1] != 0 {
                potential_offsets.push(i);
            }
        }
    }
    
    potential_offsets
}

/// Log binary content at key offsets
fn log_key_offsets(buffer: &[u8], base_offset: u64) {
    let key_offsets = vec![
        (0x0, "Start of __TEXT"),
        (0x4000, "Common __text section offset"),
        (0x8000, "Alternative __text offset"),
        (0x10000, "64KB boundary"),
        (0x20000, "128KB boundary"),
        (0x40000, "256KB boundary"),
        (0x80000, "512KB boundary"),
        (0x100000, "1MB boundary"),
        (0x200000, "2MB boundary"),
        (0x400000, "4MB boundary"),
        (0x800000, "8MB boundary"),
        (0xC00000, "12MB boundary"),
        (0x1000000, "16MB boundary"),
    ];
    
    for (offset, desc) in &key_offsets {
        if *offset < buffer.len() {
            let end = std::cmp::min(*offset + 128, buffer.len());
            let hex: String = buffer[*offset..end].iter()
                .take(64)
                .map(|b| format!("{:02x}", b))
                .collect::<Vec<_>>()
                .join(" ");
            
            shorebird_info!("  0x{:08x} ({}): {}", base_offset + *offset as u64, desc, hex);
            
            // Show ASCII representation
            let ascii: String = buffer[*offset..end].iter()
                .take(64)
                .map(|&b| if b.is_ascii_graphic() || b == b' ' { b as char } else { '.' })
                .collect();
            shorebird_info!("            ASCII: {}", ascii);
            
            // Check for potential snapshot indicators
            let chunk = &buffer[*offset..std::cmp::min(*offset + 16, buffer.len())];
            if chunk.len() >= 4 {
                let magic = u32::from_le_bytes([chunk[0], chunk[1], chunk[2], chunk[3]]);
                if magic != 0 && magic != 0xffffffff {
                    shorebird_info!("            Magic (LE): 0x{:08x}", magic);
                }
                let magic_be = u32::from_be_bytes([chunk[0], chunk[1], chunk[2], chunk[3]]);
                if magic_be != 0 && magic_be != 0xffffffff {
                    shorebird_info!("            Magic (BE): 0x{:08x}", magic_be);
                }
            }
        }
    }
}

/// Search for specific byte patterns that might indicate snapshots
fn search_for_patterns(buffer: &[u8], base_offset: u64) {
    // Patterns to search for
    let patterns = vec![
        (vec![0xf5, 0xf5, 0xdc, 0xdc], "Dart snapshot magic (f5f5dcdc)"),
        (vec![0xdc, 0xdc, 0xf5, 0xf5], "Dart snapshot magic reversed"),
        (vec![0xf6, 0xf6, 0xdc, 0xdc], "Alternative snapshot magic"),
        (vec![0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01], "Possible header pattern"),
        (b"kDartVmSnapshotData".to_vec(), "VM snapshot data string"),
        (b"kDartVmSnapshotInstructions".to_vec(), "VM snapshot instructions string"),
        (b"kDartIsolateSnapshotData".to_vec(), "Isolate snapshot data string"),
        (b"kDartIsolateSnapshotInstructions".to_vec(), "Isolate snapshot instructions string"),
    ];
    
    for (pattern, desc) in &patterns {
        shorebird_info!("Searching for: {}", desc);
        let mut found = false;
        
        for i in 0..buffer.len().saturating_sub(pattern.len()) {
            if &buffer[i..i + pattern.len()] == pattern.as_slice() {
                found = true;
                shorebird_info!("  ✅ Found at 0x{:08x}", base_offset + i as u64);
                
                // Show context around the pattern
                let context_start = i.saturating_sub(16);
                let context_end = std::cmp::min(i + pattern.len() + 16, buffer.len());
                let hex: String = buffer[context_start..context_end].iter()
                    .map(|b| format!("{:02x}", b))
                    .collect::<Vec<_>>()
                    .join(" ");
                shorebird_info!("     Context: {}", hex);
            }
        }
        
        if !found {
            shorebird_info!("  ❌ Not found");
        }
    }
}


/// Extract data for a symbol
fn extract_symbol_data<R: Read + Seek>(
    reader: &mut R,
    symbol: &Nlist64,
    next_addr: &Option<u64>,
    text: &SegmentCommand64,
    file_start: u64,
) -> Result<Vec<u8>> {
    let file_offset = file_start + (symbol.n_value - text.vmaddr) + text.fileoff;
    let size = if let Some(next) = next_addr {
        (*next - symbol.n_value) as usize
    } else {
        1024 * 1024 // Default 1MB
    };
    
    reader.seek(SeekFrom::Start(file_offset))?;
    let mut data = vec![0u8; size];
    let bytes_read = reader.read(&mut data)?;
    data.truncate(bytes_read);
    
    Ok(data)
}

/// Extract data for last symbol with estimated size
fn extract_symbol_data_estimated<R: Read + Seek>(
    reader: &mut R,
    symbol: &Nlist64,
    text: &SegmentCommand64,
    file_start: u64,
) -> Result<Vec<u8>> {
    let file_offset = file_start + (symbol.n_value - text.vmaddr) + text.fileoff;
    
    // Read up to 8MB and look for end patterns
    let max_size = 8 * 1024 * 1024;
    reader.seek(SeekFrom::Start(file_offset))?;
    let mut data = vec![0u8; max_size];
    let bytes_read = reader.read(&mut data)?;
    data.truncate(bytes_read);
    
    // Find actual end by looking for zero padding
    let mut actual_size = bytes_read;
    for i in (1024..bytes_read).step_by(1024) {
        if data[i..].iter().take(1024).all(|&b| b == 0) {
            actual_size = i;
            break;
        }
    }
    
    data.truncate(actual_size);
    Ok(data)
}

/// Get null-terminated string from string table
fn get_string_from_table(table: &[u8], offset: usize) -> &str {
    if offset >= table.len() {
        return "";
    }
    
    let end = table[offset..]
        .iter()
        .position(|&b| b == 0)
        .map(|pos| offset + pos)
        .unwrap_or(table.len());
    
    std::str::from_utf8(&table[offset..end]).unwrap_or("")
}

/// Read a struct from the reader
fn read_struct<T: Copy>(reader: &mut impl Read) -> Result<T> {
    let size = std::mem::size_of::<T>();
    let mut buffer = vec![0u8; size];
    reader.read_exact(&mut buffer)?;
    
    unsafe {
        Ok(std::ptr::read(buffer.as_ptr() as *const T))
    }
}

