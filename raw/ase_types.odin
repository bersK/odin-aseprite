package raw_aseprite_file_handler

import "core:math/fixed"

//https://github.com/aseprite/aseprite/blob/main/docs/ase-file-specs.md

// all write in le
BYTE   :: u8
WORD   :: u16
SHORT  :: i16
DWORD  :: u32
LONG   :: i32
FIXED  :: distinct i32 // 16.16
FLOAT  :: f32
DOUBLE :: f64
QWORD  :: u64
LONG64 :: i64

BYTE_N :: [dynamic]BYTE

// TODO: See if adding #packed is better
// https://odin-lang.org/docs/overview/#packed 
STRING :: struct {
    length: WORD, 
    data: []u8
}
POINT :: struct {
    x,y: LONG
}
SIZE :: struct {
    w,h: LONG
}
RECT :: struct {
    origin: POINT,
    size: SIZE,
}

PIXEL_RGBA      :: [4]BYTE
PIXEL_GRAYSCALE :: [2]BYTE
PIXEL_INDEXED   :: BYTE

PIXEL :: union {PIXEL_RGBA, PIXEL_GRAYSCALE, PIXEL_INDEXED}
TILE  :: union {BYTE, WORD, DWORD}

UUID :: [16]BYTE

ASE_Document :: struct {
    header: File_Header,
    frames: []Frame
}

Frame :: struct {
    header: Frame_Header,
    chunks: []Chunk,
}

Chunk :: struct {
    size: DWORD,
    type: Chunk_Types,
    data: Chunk_Data,
}

FILE_HEADER_SIZE :: 128
File_Header :: struct {
    size: DWORD,
    magic: WORD, // always \xA5E0
    frames: WORD,
    width: WORD,
    height: WORD,
    color_depth: WORD, // 32=RGBA, 16=Grayscale, 8=Indexed
    flags: DWORD, // 1=Layer opacity has valid value
    speed: WORD, // Not longer in use
    transparent_index: BYTE, // for Indexed sprites only
    num_of_colors: WORD, // 0 == 256 for old sprites
    ratio_width: BYTE, // "pixel width/pixel height" if 0 ratio == 1:1
    ratio_height: BYTE, // "pixel width/pixel height" if 0 ratio == 1:1
    x: SHORT,
    y: SHORT,
    grid_width: WORD, // 0 if no grid
    grid_height: WORD, // 0 if no grid
}

FRAME_HEADER_SIZE :: 16
Frame_Header :: struct {
    size: DWORD,
    magic: WORD, // always \xF1FA
    old_num_of_chunks: WORD, // if \xFFFF use new
    duration: WORD, // in milliseconds
    num_of_chunks: DWORD, // if 0 use old
}

Chunk_Data :: union{
    Old_Palette_256_Chunk, Old_Palette_64_Chunk, Layer_Chunk, Cel_Chunk, 
    Cel_Extra_Chunk, Color_Profile_Chunk, External_Files_Chunk, Mask_Chunk, 
    Path_Chunk, Tags_Chunk, Palette_Chunk, User_Data_Chunk, Slice_Chunk, 
    Tileset_Chunk,
}

Chunk_Types :: enum(WORD) {
    none,
    old_palette_256 = 0x0004,
    old_palette_64 = 0x0011,
    layer = 0x2004,
    cel = 0x2005,
    cel_extra = 0x2006,
    color_profile = 0x2007,
    external_files = 0x2008,
    mask = 0x2016, // no longer in use
    path = 0x2017, // not in use
    tags = 0x2018,
    palette = 0x2019,
    user_data = 0x2020,
    slice = 0x2022,
    tileset = 0x2023,
}

Old_Palette_Packet :: struct {
    entries_to_skip: BYTE, // start from 0
    num_colors: BYTE, // 0 == 256
    colors: [][3]BYTE
}

Old_Palette_256_Chunk :: struct {
    size: WORD,
    packets: []Old_Palette_Packet
}

Old_Palette_64_Chunk :: struct {
    size: WORD,
    packets: []Old_Palette_Packet
}

Layer_Chunk :: struct {
    flags: WORD, // to WORD -> transmute(WORD)layer_chunk.flags
    type: WORD,
    child_level: WORD,
    default_width: WORD, // Ignored
    default_height: WORD, // Ignored
    blend_mode: WORD,
    opacity: BYTE, // set when header flag is 1
    name: STRING,
    tileset_index: DWORD, // set if type == Tilemap
}

Raw_Cel :: struct{width, height: WORD, pixel: []PIXEL}
Linked_Cel :: distinct WORD
Com_Image_Cel :: struct{width, height: WORD, pixel: []PIXEL} // raw cel ZLIB compressed
Com_Tilemap_Cel :: struct{
    width, height: WORD,
    bits_per_tile: WORD, // always 32
    bitmask_id: DWORD,
    bitmask_x: DWORD,
    bitmask_y: DWORD,
    bitmask_diagonal: DWORD,
    tiles: []TILE, // ZLIB compressed
}

Cel_Chunk :: struct {
    layer_index: WORD,
    x,y: SHORT,
    opacity_level: BYTE,
    type: WORD,
    z_index: SHORT, //0=default, pos=show n layers later, neg=back
    cel: union{ Raw_Cel, Linked_Cel, Com_Image_Cel, Com_Tilemap_Cel}
}

Cel_Extra_Chunk :: struct {
    flags: WORD,
    x,y: FIXED,
    width, height: FIXED,
}

Color_Profile_Chunk :: struct {
    type: WORD,
    flags: WORD,
    fixed_gamma: FIXED,
    icc: struct {
        length: DWORD,
        data: []BYTE,
    },
}

External_Files_Chunk :: struct {
    length: DWORD,
    entries: []struct{
        id: DWORD,
        type: BYTE,
        file_name_or_id: STRING,
    }
}

Mask_Chunk :: struct {
    x: SHORT,
    y: SHORT,
    width: WORD, 
    height: WORD,
    name: STRING,
    bit_map_data: []BYTE, //size = height*((width+7)/8)
}

Path_Chunk :: struct{} // never used

Tags_Chunk :: struct {
    number: WORD,
    tags: []struct{
        from_frame: WORD,
        to_frame: WORD,
        loop_direction: BYTE,
        repeat: WORD,
        tag_color: [3]BYTE,
        name: STRING,
    }
}

Palette_Chunk :: struct {
    size: DWORD,
    first_index: DWORD,
    last_index: DWORD,
    entries: []struct {
        flags: WORD,
        red, green, blue, alpha: BYTE,
        name: STRING,
    }
}

UD_Vec :: struct {
    name: DWORD,
    type: WORD,
    data: []union {
        struct{type: WORD, data: []BYTE},
        []BYTE,
    }
}

UD_Properties_Map :: struct {
    key: DWORD,
    num: DWORD,
    property:[]struct {
        name: STRING,
        type: WORD,
        data: union {
            BYTE, SHORT, WORD, LONG, DWORD, LONG64, QWORD, FIXED, FLOAT,
            DOUBLE, STRING, SIZE, RECT, UD_Vec, 
            UD_Properties_Map, UUID
        }
    }
}

UD_Bit_4 :: struct {
    size: DWORD,
    num: DWORD,
    properties_map: []UD_Properties_Map
}

UB_Bit_2 :: [4]BYTE

User_Data_Chunk :: struct {
    flags: WORD,
    data: union{STRING, UB_Bit_2, UD_Bit_4}
}

Slice_Center :: struct{
    x: LONG,
    y: LONG, 
    width: DWORD, 
    height: DWORD,
}

Slice_Pivot :: struct{
    x: LONG, 
    y: LONG
}

Slice_Chunk :: struct {
    num_of_keys: DWORD,
    flags: DWORD,
    name: STRING,
    data: []struct{
        frams_num: DWORD,
        x,y: LONG,
        width, height: DWORD,
        data: union {Slice_Center, Slice_Pivot}
    }
}

Tileset_External :: struct{
    file_id: DWORD, 
    tileset_id: DWORD
}

Tileset_Compressed :: struct{
    length: DWORD, 
    data: []PIXEL
}

Tileset_Chunk :: struct {
    id: DWORD,
    flags: DWORD,
    num_of_tiles: DWORD,
    witdh, height: WORD,
    base_index: SHORT,
    name: STRING,
    data: union {Tileset_External, Tileset_Compressed}
}