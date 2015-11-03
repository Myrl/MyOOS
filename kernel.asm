[BITS 64]
extern GDT.data
global _kernel_main
section .text
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
%if (($ - $$) > 0x100000)
  %error "Code too large"
%endif

; VIM: let b:syntastic_nasm_nasm_post_args="-felf64"
