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
	jmp main

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

main:
	; setup data segments
	mov ax, 0
	mov ds, ax
	mov es, ax

	; setup stack
	mov ss, ax
	mov sp, 0x7C00 ; stack grows downwards

	;read something from floopy disk
	mov [ebr_drive_number], dl
	
	mov ax, 1 ; LBA = 1
	mov cl, 1
	mov bx, 0x7E00 
	call disk_read

	; print message
	mov si, msg_hello
	call puts

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

	push di
	push dx
	push cx
	push bx
	push ax
	ret

disk_reset:
	pusha
	mov ah, 0
	stc
	int 13h
	jc floopy_error
	popa
	ret

msg_hello: db "Hello world!", ENDL,  0
msg_read_failed: db "Read from disk failed!", ENDL, 0

times 510-($-$$) db 0
dw 0AA55h
