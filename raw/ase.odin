package raw_aseprite_file_handler

import "base:runtime"
import "core:fmt"
import "core:io"
import "core:os"
import "core:strings"
import "core:unicode/utf8"
import "core:encoding/endian"
import "core:slice"
import "core:log"

//https://github.com/aseprite/aseprite/blob/main/docs/ase-file-specs.md

ASE_Unmarshal_Errors :: enum{}
ASE_Unmarshal_Error :: union #shared_nil {ASE_Unmarshal_Errors, runtime.Allocator_Error}

ase_unmarshal :: proc(data: []byte, doc: ^ASE_Document, allocator := context.allocator) -> (err: ASE_Unmarshal_Error) {
    last: int
    pos := size_of(DWORD)
    // ========= FILE HEADER =========
    h: File_Header
    h.size, _ = endian.get_u32(data[last:pos], .Little)

    last = pos
    pos += size_of(WORD)
    h.magic, _ = endian.get_u16(data[last:pos], .Little)

    last = pos
    pos += size_of(WORD)
    h.frames, _ = endian.get_u16(data[last:pos], .Little)

    last = pos
    pos += size_of(WORD)
    h.width, _ = endian.get_u16(data[last:pos], .Little)

    last = pos
    pos += size_of(WORD)
    h.height, _ = endian.get_u16(data[last:pos], .Little)

    last = pos
    pos += size_of(WORD)
    h.color_depth, _ = endian.get_u16(data[last:pos], .Little)

    last = pos
    pos += size_of(DWORD)
    h.flags, _ = endian.get_u32(data[last:pos], .Little)

    last = pos
    pos += size_of(WORD)
    h.speed, _ = endian.get_u16(data[last:pos], .Little)

    last = pos
    pos += size_of(DWORD)
    last = pos
    pos += size_of(DWORD)

    last = pos
    pos += size_of(BYTE)
    h.transparent_index = data[pos]

    last = pos
    pos += size_of(BYTE) * 3

    last =  pos
    pos += size_of(WORD)
    h.num_of_colors, _ = endian.get_u16(data[last:pos], .Little)

    last = pos
    pos += size_of(BYTE)
    h.ratio_width = data[pos]

    last = pos
    pos += size_of(BYTE)
    h.ratio_height = data[pos]

    last = pos
    pos += size_of(SHORT)
    h.x, _ = endian.get_i16(data[last:pos], .Little)

    last = pos
    pos += size_of(SHORT)
    h.y, _ = endian.get_i16(data[last:pos], .Little)

    last = pos
    pos += size_of(WORD)
    h.grid_width, _ = endian.get_u16(data[last:pos], .Little)

    last = pos
    pos += size_of(WORD)
    h.grid_height, _ = endian.get_u16(data[last:pos], .Little)

    last = pos
    pos += size_of(BYTE)*84
    doc.header = h

    doc.frames = make_slice([]Frame, int(doc.header.frames), allocator) or_return

    // ======= Frames ========
    for header_count in 0..<h.frames {
        fh: Frame_Header
        last = pos
        pos += size_of(DWORD)
        fh.size, _ = endian.get_u32(data[last:pos], .Little)

        last = pos
        pos += size_of(WORD)
        fh.magic, _ = endian.get_u16(data[last:pos], .Little)

        last = pos
        pos += size_of(WORD)
        fh.old_num_of_chunks, _ = endian.get_u16(data[last:pos], .Little)

        last = pos
        pos += size_of(WORD)
        fh.duration, _ = endian.get_u16(data[last:pos], .Little)

        last = pos
        pos += size_of(BYTE) * 2

        last = pos
        pos += size_of(DWORD)
        fh.num_of_chunks, _ = endian.get_u32(data[last:pos], .Little)

        frame_count: int
        if fh.num_of_chunks == 0 {
            frame_count = int(fh.old_num_of_chunks)
        } else {
            frame_count = int(fh.num_of_chunks)
        }

        doc.frames[header_count].header = fh
        doc.frames[header_count].chunks = make_slice([]Chunk, frame_count, allocator) or_return

        for frame in 0..<frame_count {
            c: Chunk
            t_pos := pos
            last = pos
            pos += size_of(DWORD)
            c.size, _ = endian.get_u32(data[last:pos], .Little)

            last = pos
            pos += size_of(WORD)
            t_c_type, _ := endian.get_u16(data[last:pos], .Little)
            c.type = Chunk_Types(t_c_type)

            // ============ Chunks =============
            switch c.type {
            case .old_palette_256:
                last = pos
                pos += size_of(WORD)
                ct: Old_Palette_256_Chunk
                ct.size, _ = endian.get_u16(data[last:pos], .Little)
                ct.packets = make_slice([]Old_Palette_Packet, int(ct.size)) or_return

                for p in 0..<ct.size {
                    last = pos
                    pos += size_of(BYTE)
                    ct.packets[p].entries_to_skip = data[pos]

                    last = pos
                    pos += size_of(BYTE)
                    ct.packets[p].num_colors = data[pos]
                    ct.packets[p].colors = make_slice([][3]BYTE, ct.packets[p].num_colors)

                    for color in 0..<int(ct.packets[p].num_colors){
                        last = pos
                        pos += size_of(BYTE)
                        ct.packets[p].colors[color][0] = data[pos]
                        last = pos
                        pos += size_of(BYTE)
                        ct.packets[p].colors[color][1] = data[pos]
                        last = pos
                        pos += size_of(BYTE)
                        ct.packets[p].colors[color][2] = data[pos]
                    }
                }

                c.data = ct

            case .old_palette_64:
                last = pos
                pos += size_of(WORD)
                ct: Old_Palette_64_Chunk
                ct.size, _ = endian.get_u16(data[last:pos], .Little)

                for p in 0..<ct.size {
                    last = pos
                    pos += size_of(BYTE)
                    ct.packets[p].num_colors = data[pos]
                    ct.packets[p].colors = make_slice([][3]BYTE, ct.packets[p].num_colors) or_return

                    for color in 0..<int(ct.packets[p].num_colors){
                        last = pos
                        pos += size_of(BYTE)
                        ct.packets[p].colors[color][0] = data[pos]
                        last = pos
                        pos += size_of(BYTE)
                        ct.packets[p].colors[color][1] = data[pos]
                        last = pos
                        pos += size_of(BYTE)
                        ct.packets[p].colors[color][2] = data[pos]
                    }
                }
                c.data = ct

            case .layer:
                last = pos
                pos += size_of(WORD)
                ct: Layer_Chunk
                ct.flags, _ = endian.get_u16(data[last:pos], .Little)

                last = pos
                pos += size_of(WORD)
                ct.type, _ = endian.get_u16(data[last:pos], .Little)

                last = pos
                pos += size_of(WORD)
                ct.child_level, _ = endian.get_u16(data[last:pos], .Little)

                last = pos
                pos += size_of(WORD)
                ct.default_width, _ = endian.get_u16(data[last:pos], .Little)

                last = pos
                pos += size_of(WORD)
                ct.default_height, _ = endian.get_u16(data[last:pos], .Little)

                last = pos
                pos += size_of(WORD)
                ct.blend_mode, _ = endian.get_u16(data[last:pos], .Little)

                last = pos
                pos += size_of(BYTE)*3

                if (h.flags & 1) == 1 {
                    last = pos
                    pos += size_of(BYTE)
                    ct.opacity = data[pos]
                }

                last = pos
                pos += size_of(WORD)
                ct.name.length, _ = endian.get_u16(data[last:pos], .Little)
                ct.name.data = make_slice([]BYTE, int(ct.name.length)) or_return
                
                for sl in 0..<int(ct.name.length) {
                    last = pos
                    pos += size_of(BYTE)
                    ct.name.data[sl] = data[pos]
                }

                if ct.type == 2 {
                    last = pos
                    pos += size_of(DWORD)
                    ct.tileset_index, _ = endian.get_u32(data[last:pos], .Little)
                }

                c.data = ct

            case .cel:
                last = pos
                pos += size_of(WORD)
                ct: Cel_Chunk
                ct.layer_index, _ = endian.get_u16(data[last:pos], .Little)

                last = pos
                pos += size_of(SHORT)
                ct.x, _ = endian.get_i16(data[last:pos], .Little)

                last = pos
                pos += size_of(SHORT)
                ct.y, _ = endian.get_i16(data[last:pos], .Little)

                last = pos
                pos += size_of(BYTE)
                ct.opacity_level = data[pos]

                last = pos
                pos += size_of(WORD)
                ct.type, _ = endian.get_u16(data[last:pos], .Little)

                last = pos
                pos += size_of(SHORT)
                ct.z_index, _ = endian.get_i16(data[last:pos], .Little)

                last = pos
                pos += size_of(BYTE)*5

                if ct.type == 0 {
                    cel: Raw_Cel
                    last = pos
                    pos += size_of(WORD)
                    cel.width, _ = endian.get_u16(data[last:pos], .Little)

                    last = pos
                    pos += size_of(WORD)
                    cel.height, _ = endian.get_u16(data[last:pos], .Little)
                    cel.pixel = make_slice([]PIXEL, cel.height*cel.width) or_return

                    for px in 0..<int(cel.height*cel.width) {
                        last = pos
                        pos += size_of(BYTE)
                        cel.pixel[px] = data[pos]
                    }
                    ct.cel = cel

                }else if ct.type == 1 {
                    last = pos
                    pos += size_of(WORD)
                    cel, _ := endian.get_u16(data[last:pos], .Little)
                    ct.cel = Linked_Cel(cel)

                }else if ct.type == 2 {
                    cel: Com_Image_Cel
                    last = pos
                    pos += size_of(WORD)
                    cel.width, _ = endian.get_u16(data[last:pos], .Little)

                    last = pos
                    pos += size_of(WORD)
                    cel.height, _ = endian.get_u16(data[last:pos], .Little)

                    /*last = pos
                    pos += int(c.size)
                    cel.pixel = data[last:pos]*/
                    log.errorf("Compressed Images are currently unsupported. Skipping unknown number of bytes.")

                    ct.cel = cel

                }else if ct.type == 3 {
                    cel: Com_Tilemap_Cel
                    last = pos
                    pos += size_of(WORD)
                    cel.width, _ = endian.get_u16(data[last:pos], .Little)

                    last = pos
                    pos += size_of(WORD)
                    cel.height, _ = endian.get_u16(data[last:pos], .Little)

                    last = pos
                    pos += size_of(WORD)
                    cel.bits_per_tile, _ = endian.get_u16(data[last:pos], .Little)

                    last = pos
                    pos += size_of(DWORD)
                    cel.bitmask_id, _ = endian.get_u32(data[last:pos], .Little)

                    last = pos
                    pos += size_of(DWORD)
                    cel.bitmask_x, _ = endian.get_u32(data[last:pos], .Little)

                    last = pos
                    pos += size_of(DWORD)
                    cel.bitmask_y, _ = endian.get_u32(data[last:pos], .Little)

                    last = pos
                    pos += size_of(DWORD)
                    cel.bitmask_diagonal, _ = endian.get_u32(data[last:pos], .Little)

                    last = pos
                    pos += size_of(BYTE)*10

                    /*last = pos
                    pos = int(c.size)
                    cel.tiles = data[last:pos]*/
                    log.errorf("Compressed Tilemaps are currently unsupported. Skipping unknown number of bytes.")

                    ct.cel = cel
                }

                c.data = ct

            case .cel_extra:
                last = pos
                pos += size_of(WORD)
                ct: Cel_Extra_Chunk
                ct.flags, _ = endian.get_u16(data[last:pos], .Little)

                last = pos
                pos += size_of(FIXED)
                t, _ := endian.get_i32(data[last:pos], .Little)
                ct.x = auto_cast t

                last = pos
                pos += size_of(FIXED)
                t, _ = endian.get_i32(data[last:pos], .Little)
                ct.y = auto_cast t

                last = pos
                pos += size_of(FIXED)
                t, _ = endian.get_i32(data[last:pos], .Little)
                ct.width = auto_cast t

                last = pos
                pos += size_of(FIXED)
                t, _ = endian.get_i32(data[last:pos], .Little)
                ct.height = auto_cast t

                last = pos
                pos += size_of(BYTE)*16

                c.data = ct

            case .color_profile:
                last = pos
                pos += size_of(WORD)
                ct: Color_Profile_Chunk
                ct.type, _ = endian.get_u16(data[last:pos], .Little)

                last = pos
                pos += size_of(WORD)
                ct.flags, _ = endian.get_u16(data[last:pos], .Little)

                last = pos
                pos += size_of(FIXED)
                t, _ := endian.get_i32(data[last:pos], .Little)
                ct.fixed_gamma = auto_cast t

                last = pos
                pos += size_of(BYTE)*8

                if ct.type == 2 {
                    last = pos
                    pos += size_of(DWORD)
                    ct.icc.length, _ = endian.get_u32(data[last:pos], .Little)

                    last = pos
                    pos += int(ct.icc.length)
                    ct.icc.data = data[last:pos]
                }

                c.data = ct

            case .external_files:
                last = pos
                pos += size_of(DWORD)
                ct: External_Files_Chunk
                ct.length, _ = endian.get_u32(data[last:pos], .Little)
                ct.entries = make_slice([]External_Files_Entry, ct.length, allocator) or_return

                last = pos
                pos += size_of(BYTE) * 8

                for file in 0..<int(ct.length) {
                    last = pos
                    pos += size_of(DWORD)
                    ct.entries[file].id, _ = endian.get_u32(data[last:pos], .Little)

                    last = pos
                    pos += size_of(BYTE)
                    ct.entries[file].type = data[pos]

                    last = pos
                    pos += size_of(BYTE) * 7

                    last = pos
                    pos += size_of(WORD)
                    sl, _ := endian.get_u16(data[last:pos], .Little)
                    ct.entries[file].file_name_or_id.length = sl
                    ct.entries[file].file_name_or_id.data = make_slice([]u8, sl, allocator) or_return

                    last = pos
                    pos += int(sl)
                    ct.entries[file].file_name_or_id.data = data[last:pos]
                }

                c.data = ct

            case .mask:
                last = pos
                pos += size_of(SHORT)
                ct: Mask_Chunk
                ct.x, _ = endian.get_i16(data[last:pos], .Little)

                last = pos
                pos += size_of(SHORT)
                ct.y, _ = endian.get_i16(data[last:pos], .Little)

                last = pos
                pos += size_of(WORD)
                ct.width, _ = endian.get_u16(data[last:pos], .Little)

                last = pos
                pos += size_of(WORD)
                ct.height, _ = endian.get_u16(data[last:pos], .Little)

                last = pos
                pos += size_of(BYTE)*8

                last = pos
                pos += size_of(WORD)
                ct.name.length, _ = endian.get_u16(data[last:pos], .Little)
                ct.name.data = make_slice([]u8, ct.name.length, allocator) or_return

                last = pos
                pos += int(ct.name.length)
                ct.name.data = data[last:pos]

                last = pos
                pos += int(ct.height * ((ct.width + 7) / 8))
                ct.bit_map_data = data[last:pos]

                c.data = ct

            case .path:
                ct: Path_Chunk
                c.data = ct

            case .tags:
                last = pos
                pos += size_of(WORD)
                ct: Tags_Chunk
                ct.number, _ = endian.get_u16(data[last:pos], .Little)
                ct.tags = make_slice([]Tag, int(ct.number), allocator) or_return

                last = pos
                pos += size_of(BYTE) * 8

                for tag in 0..<int(ct.number) {
                    last = pos
                    pos += size_of(WORD)
                    ct.tags[tag].from_frame, _ = endian.get_u16(data[last:pos], .Little)

                    last = pos
                    pos += size_of(WORD)
                    ct.tags[tag].to_frame, _ = endian.get_u16(data[last:pos], .Little)

                    last = pos
                    pos += size_of(BYTE)
                    ct.tags[tag].loop_direction = data[pos]

                    last = pos
                    pos += size_of(WORD)
                    ct.tags[tag].repeat, _ = endian.get_u16(data[last:pos], .Little)

                    last = pos
                    pos += size_of(BYTE) * 6

                    last = pos
                    pos += size_of(BYTE)
                    ct.tags[tag].tag_color[0] = data[pos]

                    last = pos
                    pos += size_of(BYTE)
                    ct.tags[tag].tag_color[1] = data[pos]

                    last = pos
                    pos += size_of(BYTE)
                    ct.tags[tag].tag_color[2] = data[pos]

                    last = pos
                    pos += size_of(BYTE)

                    last = pos
                    pos += size_of(WORD)
                    ct.tags[tag].name.length, _ = endian.get_u16(data[last:pos], .Little)
                    ct.tags[tag].name.data = make_slice([]u8, ct.tags[tag].name.length, allocator) or_return

                    last = pos
                    pos += int(ct.tags[tag].name.length)
                    ct.tags[tag].name.data = data[last:pos]
                }

                c.data = ct

            case .palette:
                last = pos
                pos += size_of(DWORD)
                ct: Palette_Chunk
                ct.size, _ = endian.get_u32(data[last:pos], .Little)

                last = pos
                pos += size_of(DWORD)
                ct.first_index, _ = endian.get_u32(data[last:pos], .Little)

                last = pos
                pos += size_of(DWORD)
                ct.last_index, _ = endian.get_u32(data[last:pos], .Little)

                length := int(ct.last_index - ct.first_index + 1)
                ct.entries = make_slice([]Palette_Entry, length, allocator) or_return

                last = pos
                pos += size_of(BYTE) * 8

                for entry in 0..<length {
                    last = pos
                    pos += size_of(WORD)
                    ct.entries[entry].flags, _ = endian.get_u16(data[last:pos], .Little)

                    last = pos
                    pos += size_of(BYTE)
                    ct.entries[entry].red = data[pos]

                    last = pos
                    pos += size_of(BYTE)
                    ct.entries[entry].green = data[pos]

                    last = pos
                    pos += size_of(BYTE)
                    ct.entries[entry].blue = data[pos]

                    last = pos
                    pos += size_of(BYTE)
                    ct.entries[entry].alpha = data[pos]

                    if ct.entries[entry].flags == 1 {
                        last = pos
                        pos += size_of(WORD)
                        ct.entries[entry].name.length, _ = endian.get_u16(data[last:pos], .Little)

                        last = pos
                        pos += int(ct.entries[entry].name.length)
                        ct.entries[entry].name.data = data[last:pos]
                    }
                    
                }

                c.data = ct

            case .user_data:
                last = pos
                pos += size_of(DWORD)
                ct: User_Data_Chunk
                ct.flags, _ = endian.get_u32(data[last:pos], .Little)

                if (ct.flags & 1) == 1 {
                    str: STRING
                    last = pos
                    pos += size_of(WORD)
                    str.length, _ = endian.get_u16(data[last:pos], .Little)
                    str.data = make_slice([]u8, int(str.length), allocator) or_return

                    last = pos
                    pos += int(str.length)
                    str.data = data[last:pos]

                    ct.text = str
                }
                
                if (ct.flags & 2) == 2 {
                    color: UB_Bit_2
                    last = pos
                    pos += size_of(BYTE)
                    color[0] = data[pos]

                    last = pos
                    pos += size_of(BYTE)
                    color[1] = data[pos]

                    last = pos
                    pos += size_of(BYTE)
                    color[2] = data[pos]

                    last = pos
                    pos += size_of(BYTE)
                    color[3] = data[pos]
                }
                
                if (ct.flags & 4) == 4 {
                    last = pos
                    pos += size_of(DWORD)
                    skipped, _ := endian.get_u32(data[last:pos], .Little)
                    log.errorf("User Data Properties Maps are currently unsupported. Skipping %v bytes.", skipped)

                    last = pos
                    pos += int(skipped)
                }

                c.data = ct

            case .slice:
                last = pos
                pos += size_of(DWORD)
                ct: Slice_Chunk
                ct.num_of_keys, _ = endian.get_u32(data[last:pos], .Little)

                last = pos
                pos += size_of(DWORD)
                ct.flags, _ = endian.get_u32(data[last:pos], .Little)

                last = pos
                pos += size_of(DWORD)

                last = pos
                pos += size_of(WORD)
                ct.name.length, _ = endian.get_u16(data[last:pos], .Little)
                ct.name.data = make_slice([]u8, int(ct.name.length), allocator) or_return

                last = pos
                pos += int(ct.name.length)
                ct.name.data = data[last:pos]

                ct.data = make_slice([]Slice_Key, int(ct.num_of_keys), allocator) or_return

                for key in 0..<ct.num_of_keys{
                    last = pos
                    pos += size_of(DWORD)
                    ct.data[key].frame_num, _ = endian.get_u32(data[last:pos], .Little)

                    last = pos
                    pos += size_of(LONG)
                    ct.data[key].x, _ = endian.get_i32(data[last:pos], .Little)

                    last = pos
                    pos += size_of(LONG)
                    ct.data[key].y, _ = endian.get_i32(data[last:pos], .Little)

                    last = pos
                    pos += size_of(DWORD)
                    ct.data[key].width, _ = endian.get_u32(data[last:pos], .Little)

                    last = pos
                    pos += size_of(DWORD)
                    ct.data[key].height, _ = endian.get_u32(data[last:pos], .Little)
                    
                    if (ct.flags & 1) == 1 {
                        center: Slice_Center
                        last = pos
                        pos += size_of(LONG)
                        center.x, _ = endian.get_i32(data[last:pos], .Little)

                        last = pos
                        pos += size_of(LONG)
                        center.y, _ = endian.get_i32(data[last:pos], .Little)

                        last = pos
                        pos += size_of(DWORD)
                        center.width, _ = endian.get_u32(data[last:pos], .Little)

                        last = pos
                        pos += size_of(DWORD)
                        center.height, _ = endian.get_u32(data[last:pos], .Little)

                        ct.data[key].center = center
                    }

                    if (ct.flags & 2) == 2 {
                        pivot: Slice_Pivot
                        last = pos
                        pos += size_of(LONG)
                        pivot.x, _ = endian.get_i32(data[last:pos], .Little)

                        last = pos
                        pos += size_of(LONG)
                        pivot.y, _ = endian.get_i32(data[last:pos], .Little)

                        ct.data[key].pivot = pivot
                    }

                }

                c.data = ct

            case .tileset:
                last = pos
                pos += size_of(DWORD)
                ct: Tileset_Chunk
                ct.id, _ = endian.get_u32(data[last:pos], .Little)

                last = pos
                pos += size_of(DWORD)
                ct.flags, _ = endian.get_u32(data[last:pos], .Little)

                last = pos
                pos += size_of(DWORD)
                ct.num_of_tiles, _ = endian.get_u32(data[last:pos], .Little)

                last = pos
                pos += size_of(WORD)
                ct.width, _ = endian.get_u16(data[last:pos], .Little)

                last = pos
                pos += size_of(WORD)
                ct.height, _ = endian.get_u16(data[last:pos], .Little)

                last = pos
                pos += size_of(SHORT)
                ct.base_index, _ = endian.get_i16(data[last:pos], .Little)

                last = pos
                pos += size_of(BYTE) * 14

                last = pos
                pos += size_of(WORD)
                ct.name.length, _ = endian.get_u16(data[last:pos], .Little)
                ct.name.data = make_slice([]u8, int(ct.name.length), allocator) or_return

                last = pos
                pos += int(ct.name.length)
                ct.name.data = data[last:pos]

                if (ct.flags & 1) == 1 {
                    ext: Tileset_External
                    last = pos
                    pos += size_of(DWORD)
                    ext.file_id, _ = endian.get_u32(data[last:pos], .Little)

                    last = pos
                    pos += size_of(DWORD)
                    ext.tileset_id, _ = endian.get_u32(data[last:pos], .Little)

                    ct.external = ext
                }
                if (ct.flags & 2) == 2 {
                    img_set: Tileset_Compressed
                    last = pos
                    pos += size_of(DWORD)
                    img_set.length, _ = endian.get_u32(data[last:pos], .Little)
                    img_set.data = make_slice([]u8, int(img_set.length), allocator) or_return

                    last = pos
                    pos += int(img_set.length)
                    img_set.data = data[last:pos]
                    
                }
                c.data = ct

            case .none:
            case: unreachable()
            }
            last = pos
            pos = t_pos + int(c.size)

            doc.frames[header_count].chunks[frame] = c
        }
    }

    
    return
}