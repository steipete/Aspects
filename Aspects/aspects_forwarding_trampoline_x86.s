#if defined(__i386__)
.text
.align 12
.globl _aspects_forwarding_trampoline_page

_aspects_forwarding_trampoline_page:
_aspects_forwarding_trampoline:
    popl %eax           // pop saved pc (address of first of the three nops)
    subl $4096+5, %eax  // offset address by one page and the length of the call instrux
    pushl %eax          // save pointer to trampoline data (IMP+SEL)
    movl 4(%eax), %eax  // fetch selector to use
    movl %eax, 12(%esp) // patch second argument
    popl %eax           // restore data pointer
    movl (%eax), %eax   // fetch pointer to objc_sendMsg
    jmp *%eax           // jump to it as if nothing happened
    nop                 // align to page
    nop
    nop
    nop
    nop

// 509 trampoline entry points
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop
call _aspects_forwarding_trampoline
nop
nop
nop

#endif