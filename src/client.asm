; Atari XEX header is generated automatically by MADS with -o:*.xex

        icl 'vbxe_const.asm'

CIOV    = $E456
ICCOM   = $0342
ICBAL   = $0344
ICBAH   = $0345
ICBLL   = $0348
ICBLH   = $0349

VIEW_TIMEOUT = 240
READ_LIMIT   = 192
KEY_D        = $3A
DEMO_HEIGHT  = 200
DEMO_STAMP_SIZE = 20
ROOM_NAME_MAX = 32
ROOM_HOVER_MAX_SELECTIONS = 6
ROOM_HOVER_NAME_MAX = 19
ROOM_SELECTION_CACHE_SLOTS = 4
DEMO_CURSOR_MAX_X = 159
DEMO_CURSOR_MAX_Y = 199
DEMO_CURSOR_START_X = 76
DEMO_CURSOR_START_Y = 96
DEMO_CURSOR_COLOR = 1
DEMO_CURSOR_WIDTH = 16
DEMO_POPUP_WIDTH = 160
DEMO_POPUP_WIDTH_LOGICAL = 80
DEMO_POPUP_INNER_WIDTH = 158
DEMO_POPUP_LINES_MAX = 3
DEMO_POPUP_LINE_STRIDE = 20
DEMO_POPUP_TEXT_MAX = 19
DEMO_POPUP_CHAR_WIDTH_LOGICAL = 4
DEMO_POPUP_TEXT_X = 2
DEMO_POPUP_TEXT_Y = 2
DEMO_POPUP_HEIGHT = 28
DEMO_POPUP_LAST_ROW = 27
DEMO_POPUP_MAX_X = 80
DEMO_POPUP_MAX_Y = 172
DEMO_POPUP_BORDER_COLOR = 250
DEMO_POPUP_FILL_COLOR = 24
DEMO_POPUP_TEXT_COLOR = 252

STUB_BASE      = $0600
STUB_TIRQ_EXIT = STUB_BASE+17

zp_demo_cursor_x = $B0
zp_demo_cursor_y = $B1
zp_demo_prev_x   = $B2
zp_demo_prev_trig = $B3
zp_mouse_dx      = $B4
zp_mouse_dy      = $B5
zp_demo_prev_y   = $B6

        org $2000

        icl 'client/boot.asm'
        icl 'client/input.asm'
        icl 'client/popup.asm'
        icl 'client/cursor.asm'
        icl 'client/text_io.asm'
        icl 'client/room_actions.asm'
        icl 'client/graphics_patch.asm'
        icl 'client/image_io.asm'
        icl 'client/demo_image.asm'
        icl 'client/display_debug.asm'
        icl 'client/status_bar.asm'
        icl 'fujinet.asm'
        icl 'client/assets.asm'
        icl 'client/state.asm'

        run main