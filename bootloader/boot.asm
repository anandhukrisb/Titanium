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

	; read something from the floppy disk
	; BIOS should set DL to drive number

	mov [ebr_drive_number], dl

	mov ax, 1							; LBA = 1, second sector from the disk
	mov cl, 1							; 1 sector to read
	mov bx, 0x7E00						; Data should be after the bootloader
	call disk_read

	;prints the message
	mov si, msg_hello
	call puts

	hlt

;
;	Error handlers
;

floppy_error:
	mov si, msg_read_failed
	call puts

	jmp wait_key_and_reboot
	hlt

wait_key_and_reboot:
	mov ah, 0
	int 16h
	jmp 0FFFFH:0						; Jumping to the beggining of the BIOS, should reboot

.halt:
	cli
	hlt									; Disabling the interrupts, this way CPU can get out of the halt state


;
;	Disk Routines
;

;
;	Converts an LBS address to CHS address
;	Parameters:
;		- ax: LBA Address
;	Returns:
;		- cx [bits 0-5]: sector number
;		- cx [bits 6-15]: cylinder
;		- dh: head
;

lbs_to_chs:

	push ax
	push dx

	xor dx, dx							; effienctly making value in dx to zero
	div word [bdb_sectors_per_track]	; ax = LBS / sectors_per_track
										; dx = LBS % sectors_per_track

	inc dx								; incrementing value in dx
	mov cx, dx							; sector number

	xor dx, dx
	div word [bdb_heads]				; ax = ( LBS / sectors_per_track ) / head = cylinder
										; dx = ( LBS / sectors_per_track ) % head = head
	mov dh, dl							; dh = head
	mov ch, al
	shl ah, 6
	or cl, ah

	pop ax
	mov dl, al							; restore DL
	pop ax
	ret

;
;	Reads sectors from a disk
;	Parameters
;		- ax: LBA address
;		- cl: Number of sectors to read
;		- dl: Drive number
;		- es:bx: memory address where to store data

disk_read:

	push ax
	push bx
	push cx
	push dx
	push di

	push cx								; Temporarily store cx (number of sectors to read)
	call lbs_to_chs						; Compute CHS
	pop ax								; AL = number of sectors to read

	mov ah, 02h
	mov di, 3							; Retry count

.retry:
	pusha								; saving all registers
	stc									; set carry flag, some BIOS'es dont set it
	int 13h
	jnc .done

	;read failed
	popa
	call disk_reset

	dec di
	test di, di
	jnz .retry

.fail:
	jmp floppy_error

.done:
	push di
	push dx
	push cx
	push bx
	push ax

	ret

;
; Reset Disk controller
; Parameters:
;	dl: drive number

disk_reset:
	pusha

	mov ah, 0
	stc
	int 13h
	jc floppy_error
	popa
	ret



msg_hello: 					db 'Hello World!', ENDL, 0
msg_read_failed:			db 'Read from disk failed!', ENDL, 0

times 510-($-$$) db 0

dw 0AA55h