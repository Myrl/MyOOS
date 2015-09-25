[BITS 32]
%define BOS 0x100000
org BOS
MBALIGN		equ 1<<0
MEMINFO		equ 1<<1
MKLUDGE 	equ 1<<16
FLAGS		equ MBALIGN | MEMINFO |MKLUDGE
MAGIC		equ 0x1BADB002
CHECKSUM	equ -(MAGIC + FLAGS)

section .text

multiboot:
align 4
	dd MAGIC
	dd FLAGS
	dd CHECKSUM

aout_k:
	dd multiboot
	dd multiboot
	dd _bss
	dd _end
	dd _start

;--------------------------------
align 4

GDT:
.null: equ $ - GDT
	dq 0
.code: equ $ - GDT
	dw 0
	dw 0
	db 0
	db 0x98
	db 0x20
	db 0
.data: equ $ - GDT
	dw 0
	dw 0
	db 0
	db 0x90
	db 0x00
	db 0

GDTR:
	dw 0x17
	dq GDT
;--------------------------------
do_nothing:
	iret
;--------------------------------
_start:
paging_setup:
	mov edi, paging.pml4t
	mov cr3, edi
	.pml4t:
		mov dword [edi], (paging.pdpt0 - $$ + BOS) | 3
		add edi, 0x1000
	.pdpt:
		mov dword [edi], (paging.pd0 - $$ + BOS) | 3
		add edi, 0x1000
	.pd:
		mov dword [edi], (paging.pt0 - $$ + BOS) | 3
		add edi, 0x1000
	.identity:
		mov eax, 0x00000003
		mov ecx, 512
	.identity_loop:
		mov dword [edi], eax
		add eax, 0x1000
		add edi, 8
		loop .identity_loop
	mov eax, cr4
	or eax, 1 << 5
	mov cr4, eax

long_mode_switch:
	.lm_bit:
		mov ecx, 0xc0000080
		rdmsr
		or eax, 1 << 8
		wrmsr
	.paging:
		mov eax, cr0
		or eax, 1 << 31
		mov cr0, eax
	.jump:
		lgdt [GDTR]
		jmp GDT.code:_kernel_main
[BITS 64]
_kernel_main:
    cli
    mov ax, GDT.data
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov rdi, 0xB8000
    mov rax, 0x1F201F201F201F20
    mov rcx, 40
    rep stosq
    hlt
_bss:
align 0x1000
paging:
    .pml4t   resq 512
    .pdpt0   resq 512
    .pd0     resq 512
    .pt0     resq 512
_end:
%if (($ - $$) > 0x100000)
  %error "Code too large"
%endif
