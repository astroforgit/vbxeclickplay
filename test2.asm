opt h+
    org $2000

VBXE_BASE       equ $D600
VBXE_BLC_ADR    equ VBXE_BASE + $50
VBXE_BLT_BUSY   equ VBXE_BASE + $53

MAX_ENEMIES     equ 4   ; Let's draw 4 colorful enemies

; --- ENEMY ARRAYS (State and Position) ---
; We store the 24-bit screen memory address for each enemy
enemy_pos_l     dta b($10, $50, $90, $D0) ; X-spacing
enemy_pos_m     dta b($0A, $0A, $0A, $0A) ; Y-spacing
enemy_pos_h     dta b($00, $00, $00, $00) 

; Animation Frame tracker (0 = Frame 1, 1 = Frame 2)
enemy_frame     dta b(0, 1, 0, 1)         ; Staggered animations
enemy_alive     dta b(1, 1, 1, 1)         ; 1 = Alive, 0 = Dead/Exploded

; ==========================================================
; ENEMY MANAGER ROUTINE (Call this once per frame)
; ==========================================================
draw_swarm:
    ldx #0                  ; X register will be our enemy counter (0 to 3)

swarm_loop:
    lda enemy_alive,x       ; Is this enemy dead?
    beq next_enemy          ; If 0, skip drawing

    ; 1. Wait for Blitter
    jsr wait_blitter

    ; 2. Update BCB Destination Address for this specific enemy
    lda enemy_pos_l,x
    sta bcb_draw_alien_dst
    lda enemy_pos_m,x
    sta bcb_draw_alien_dst+1
    lda enemy_pos_h,x
    sta bcb_draw_alien_dst+2

    ; 3. Setup Animation Frame (The "Fancy" part)
    ; By simply changing the SOURCE address in the BCB, we swap 
    ; all the 256-color graphics instantly without moving any data!
    lda enemy_frame,x
    beq set_frame_1
    
set_frame_2:
    lda #$40                ; Frame 2 sits at $011040
    sta bcb_draw_alien_src
    jmp fire_blitter
    
set_frame_1:
    lda #$00                ; Frame 1 sits at $011000
    sta bcb_draw_alien_src

fire_blitter:
    ; 4. Tell Blitter to draw this alien
    mva #<bcb_draw_alien VBXE_BLC_ADR
    mva #>bcb_draw_alien VBXE_BLC_ADR+1
    mva #$01 VBXE_BLC_ADR+2

next_enemy:
    inx                     ; Move to next enemy
    cpx #MAX_ENEMIES
    bne swarm_loop          ; Loop until all 4 are drawn
    rts

wait_blitter:
    lda VBXE_BLT_BUSY
    bne wait_blitter
    rts

; ==========================================================
; BLITTER CONTROL BLOCK FOR ALIENS
; ==========================================================
bcb_draw_alien:
bcb_draw_alien_src:
    dta b($00)                  ; 0: Source Low (Dynamically updated for animation)
    dta b($10), b($01)          ; 1,2: Source Mid/High ($0110xx)
    dta b(0), b(1)              ; 3,4: Source Step
    
bcb_draw_alien_dst:
    dta b($00), b($00), b($00)  ; 5,6,7: Dest (Dynamically updated per enemy)
    dta b(0), b(1)              ; 8,9: Dest Step
    
    dta w(7)                    ; 10,11: Width (8 pixels, 0-7)
    dta b(7)                    ; 12: Height (8 pixels, 0-7)
    
    dta b($FF), b($00)          ; 13,14: AND/XOR masks
    dta b($FF)                  ; 15: Collision mask (Still detect player bullets!)
    dta b($00), b($00)          ; 16,17: Zoom, Pattern
    
    ; Control Byte: %00001001 
    ; (Enable Transparency so the black $00 background doesn't draw a box around the alien!)
    dta b(%00001001)