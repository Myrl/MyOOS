[BITS 32]

MBALIGN		equ 1<<0
MEMINFO		equ 1<<1
FLAGS		equ MBALIGN | MEMINFO
ARCHITECTURE	equ 0
MAGIC		equ 0xE85250D6
LENGTH		equ multiboot_end - multiboot_tags
CHECKSUM	equ -(MAGIC + ARCHITECTURE + LENGTH)

global _start
global GDT.data
extern _kernel_main

section .multiboot
align 4
multiboot:
	dd MAGIC
	dd ARCHITECTURE
	dd LENGTH
	dd CHECKSUM
multiboot_tags:
multiboot_term:
	type	dd 0
	flags	dd 0
	size	dd 8
multiboot_end:


section .gdt
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

section .bss
align 0x1000
paging:
    .pml4t   resq 512
    .pdpt0   resq 512
    .pd0     resq 512
    .pt0     resq 512

section .text
_start:
paging_setup:
	mov edi, paging.pml4t
	mov cr3, edi
	.pml4t:
		mov dword [edi], paging.pdpt0
		or edi, 3
		add edi, 0x1000
	.pdpt:
		mov dword [edi], paging.pd0
		or edi, 3
		add edi, 0x1000
	.pd:
		mov dword [edi], paging.pt0
		or edi, 3
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
;		jmp GDT.code:_kernel_main

; VIM: let b:syntastic_nasm_nasm_post_args="-f elf64"
