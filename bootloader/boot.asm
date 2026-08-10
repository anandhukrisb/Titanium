org 0X7C00
bits 16

%define ENDL 0x0D, 0x0A

;
;	FAT12 Headers
;
jmp short start
nop

bdb_oem:                        db 'MSWIN4.1'		; 8 bytes
bdb_bytes_per_sector:           dw 512
bdb_sectors_per_cluster:        db 1
bdb_reserved_sectores:          dw 1
bdb_fat_count:                  db 2
bdb_dir_entries_count:          dw 0E0H
bdb_total_sectors:              dw 2880             ; 2880 * 512 = 1.44 MB
bdb_media_descriptor_type:      db 0F0H             ; 3.5" floppy disc
bdb_sectors_per_fat:            dw 9                ; 9 sectors/fat
bdb_sectors_per_track:          dw 18
bdb_heads:                      dw 2
bdb_hidded_sectors:             dd 0
bdb_large_sector_count:         dd 0


;
;	extended boot record
;
ebr_drive_number:               db 0                 ; 0x00 floppy, 0x80 hdd, useless
								db 0                 ; reserved byte
ebr_signature:                  db 29h
ebr_volume_id:                  db 12h, 34h, 56h, 78h; serial number, values doesnt matter
ebr_volume_label:               db 'TITANIUM OS'     ; 11 bytes, padded with spaces
ebr_system_id:                  db 'FAT12   '        ; 8 bytes

;
;	code goes here
;

; gonna learn some disk layout



start:
	jmp main

;Prints a string to the screen
;Params:
;	-ds:si points to string

puts:
	push si
	push ax

.loop:
	lodsb	;loads next character in al
	or al, al	;is the next character null?
	jz .done

	mov ah, 0x0e	;bios interrupt called(teletype ouput function selected)
	mov bh, 0
	int 0x10
	
	jmp .loop

.done:
	pop ax
	pop si
	ret

main:
	; setup data segments

	mov ax, 0
	mov ds, ax
	mov es, ax

	; setup stack
	mov ss, ax
	mov sp,0X7C00

	;prints the message
	mov si, msg_hello
	call puts

	hlt

.halt:
	jmp .halt

msg_hello: db 'Hello World!', ENDL, 0

times 510-($-$$) db 0

dw 0AA55h
