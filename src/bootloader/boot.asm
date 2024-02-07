org 0x7C00
bits 16

%define ENDL 0x0D, 0x0A ; endline for line breaking

;
; FAT12 header
;
jmp short start
nop

bdb_oem:	db 'MSWIN4.1' ; 8bytes
bdb_bytes_per_sector:	dw 512
bdb_sectors_per_cluster: 	db 1
bdb_reserved_sectors:	dw 1
bdb_fat_count:	db 2
bdb_dir_entries_count: dw 0E0h
bdb_total_sectors:	dw 2880 ; 2880 * 512 = 1.44MB
bdb_media_descriptor_type:	db 0F0h ; F0 = 3.5 floopy disk
bdb_sectors_per_fat: 	dw 9 ; 9 sectors/fat
bdb_sectors_per_track:	dw 18
bdb_heads:	dw 2
bdb_hidden_sectors:	dd 0
bdb_large_sector_count:	dd 0

; extended boot record
ebr_drive_number:	db 0 ; 0x0 = floppy, 0x80 = hdd
					db 0 ; reserved
ebr_signature:	db 29h
ebr_volume_id:	db 12h, 34h, 56h, 78h ; serial number, value doesn't matter
ebr_volume_label:	db 'OPERETING!!'
ebr_system_id:	db 'FAT12   ' ; 8 bytes

;
; Code goes here
;


start:
	; setup data segments
	mov ax, 0
	mov ds, ax
	mov es, ax

	; setup stack
	mov ss, ax
	mov sp, 0x7C00 ; stack grows downwards

	push es
	push word .after
	retf

.after:
	; read something from floopy disk
	mov [ebr_drive_number], dl
	
	; show loading message
	mov si, msg_loading
	call puts

	; read drive parameter
	push es
	mov ah, 08h
	int 13h
	jc floopy_error
	pop es

	and cl, 0x3F ; remove top 2 bits
	xor ch, ch 
	mov [bdb_sectors_per_track], cx ; sector count

	inc dh
	mov [bdb_heads], dh ; head count

	; read FAT root directory
	mov ax, [bdb_sectors_per_fat] ; compute LBA of root dir = reserved + fats * sectors_per_fat
	mov bl, [bdb_fat_count]
	xor bh, bh
	mul bx ; ax = (fat * sectors_per_fat)
	add ax, [bdb_reserved_sectors] ; ax = LBA of root dir
	push ax

	; compute size of root dir = (32 * number_of_entries) / bytes_per_sector
	mov ax, [bdb_dir_entries_count]
	shl ax, 5 ; ax *= 32
	xor dx, dx ; dx = 0
	div word [bdb_bytes_per_sector] ; number of sectors we need to read

	test dx, dx ; if dx != 0, add 1
	jz root_dir_after
	inc ax ; division remainder != 0, add 1
		   ; this means we have a sector only partially filled with entries

.root_dir_after:
	; read root directory
	mov cl, al ; cl = number of sectors to read = size of root directory
	pop ax ; ax = LBA of root directory
	mov dl, [ebr_drive_number] ; dl = drive number (we saved it previously)
	mov bx, buffer ; es:bx = buffer

	call disk_read

	; search for kernel.bin
	xor bx, bx
	mov di, buffer

.search_kernel:
	

	cli
	hlt

;
; Error handler
;

floopy_error:
	mov si, msg_read_failed
	call puts
	jmp wait_key_and_reboot

wait_key_and_reboot:
	mov ah, 0
	int 16h ; wait for keypress
	jmp 0FFFFh:0 ; jump to beginning of BIOS. should reboot
	hlt

.halt:
	cli
	hlt

puts:
	push si
	push ax

.loop:
	lodsb ; load next charactor in al
	or al, al ; verify if next charactor is null?
	jz .done

	mov ah, 0x0E
	mov bh, 0
	int 0x10
	
	jmp .loop

.done:
	pop ax
	pop si
	ret

;
; Disk routines
;

lba_to_chs:
	push ax
	push dx

	xor dx, dx ; dx = 0
	div word [bdb_sectors_per_track] ; ax = LBA / SectorsPerTrack
									 ; dx = LBA % SectorsPerTrack
	inc dx ; dx = (LBA % SectorsPerTrack + 1) = sector
	mov cx, dx ; cx = sector

	xor dx, dx
	div word [bdb_heads] ; ax = (LBA / SectorsPerTrack) / Heads = cylinder
						 ; dx = (LBA / SectorsPerTrack) % Heads = head
	mov dh, dl ; dh = head
	mov ch, al ; ch = Cylinder ( lower & 8bit)
	shl ah, 6
	or cl, ah ; put upper 2 bits of cylinder in CL

	pop ax
	mov dl, al ; restore DL
	pop ax
	ret

disk_read:
	push ax
	push bx
	push cx
	push dx
	push di

	push cx ; temporarily save CL (number of sectors to read)
	call lba_to_chs
	pop ax ; AL = number of sectors to read

	mov ah, 02h
	mov di, 3 ; retry count

.retry:
	pusha
	stc
	int 13h
	jnc .done

	; failed
	popa
	call disk_reset

	dec di
	test di, di
	jnz .retry
 
.fail:
	jmp floopy_error

.done:
	popa

	pop di
	pop dx
	pop cx
	pop bx
	pop ax
	ret

disk_reset:
	pusha
	mov ah, 0
	stc
	int 13h
	jc floopy_error
	popa
	ret

msg_loading: db "Loading...", ENDL,  0
msg_read_failed: db "Read from disk failed!", ENDL, 0

times 510-($-$$) db 0
dw 0AA55h

buffer: