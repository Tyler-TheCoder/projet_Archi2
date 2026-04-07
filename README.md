
# 8086 Assembly Project: Matrix Preprocessing with Periodic Interrupts

## Project Overview
---
This project asks you to create a sophisticated assembly language program that demonstrates the fundamental concept of interrupt-driven programming on the 8086 microprocessor. The core idea is to build a program that appears to run continuously in the background, but periodically pauses itself every thirty seconds to display educational content about matrix data processing.

Think of it like a slideshow presentation that advances automatically, except instead of clicking a button, the computer's internal timer triggers the transition. This mimics how real operating systems handle multitasking, where the timer interrupt allows the OS to switch between different programs.

## Understanding the Interrupt Mechanism
---
### The Hardware Timer Chain

The 8086 computer has a hardware timer chip that generates a signal approximately 18.2 times every second. This creates a heartbeat for the computer. Each time this timer ticks, it triggers interrupt number 08h. The handler for INT 08h does important system timing work, and then it calls `INT 1Ch` as a courtesy to programmers who want to hook into this timing mechanism.

The beautiful thing about INT 1Ch is that it arrives with perfect regularity but does nothing by default. This makes it the ideal interrupt to hijack for your own timing purposes. By replacing the INT 1Ch handler with your own code, you can count these timer ticks and take action when enough time has passed.

### Calculating Time Intervals

Since INT 1Ch fires 18.2 times per second, you can calculate how many ticks equal any time period. For thirty seconds, you need approximately 546 ticks (18.2 multiplied by 30). Your interrupt handler will maintain a counter, incrementing it each time INT 1Ch fires. When the counter reaches 546, you know thirty seconds have elapsed, so you trigger the next task and reset the counter.

## Program Architecture
---
### Main Program Structure

Your main program needs to accomplish several things in sequence. First, it must initialize the matrix data in memory. Then it needs to save the current INT 1Ch vector from the interrupt vector table and install your custom handler in its place. After that, the main program enters an infinite loop, essentially doing nothing while waiting for the interrupt handler to do all the work. When all tasks have been displayed, the program restores the original INT 1Ch handler and exits cleanly.

The key instructions you will use include the CLI instruction to disable interrupts temporarily while you modify the interrupt vector table, ensuring no interrupt fires while you are halfway through changing the pointer. After setting up the new handler, you use STI to re-enable interrupts. To read the current INT 1Ch vector, you will use INT 21h with function 35h. To set a new vector, you use INT 21h with function 25h.

### Interrupt Handler Design

Your custom INT 1Ch handler is where the magic happens. Every 55 milliseconds, this handler executes. It must be extremely efficient because it interrupts the normal program flow. The handler should increment your tick counter and check if it has reached 546. If not, it simply exits using IRET. If thirty seconds have passed, it sets a flag indicating a task should be displayed, resets the counter, and returns.

An important consideration is that the actual task display should not happen inside the interrupt handler itself. Interrupt handlers should be short and fast. Instead, the handler sets a flag, and the main program loop checks this flag. When the flag is set, the main program calls the appropriate task procedure, displays it, and clears the flag.

## Task Implementation Guide
---
### Task 1: Display Original Matrix

This task introduces the matrix and highlights problematic data. You need to iterate through each element of the matrix, checking whether each character is a digit between '0' and '9'. You can do this by comparing the ASCII value of each character. Digits have ASCII values from 48 to 57 (30h to 39h in hexadecimal).

To display characters with color, you will use INT 10h function 09h, which writes a character with a specific attribute. The attribute byte controls both foreground and background color. For red text on black background, the attribute is 0Ch (or 04h for dark red). For normal white text, use 07h.

The key instructions here are the LODSB instruction to load a byte from the matrix into AL, the CMP instruction to compare it against '0' and '9', and conditional jumps like JB (jump if below) and JA (jump if above) to determine if the character is outside the digit range. You will also use INT 10h with function 02h to position the cursor before printing each character.

### Task 2: Clean Matrix Data

This task builds on Task 1 but actually modifies the matrix in memory. After detecting a non-digit character, instead of just displaying it differently, you replace it with '0' in the matrix itself. This requires using the STOSB instruction or a direct memory write using MOV [SI], '0'.

The challenge here is maintaining two representations: the original matrix and the cleaned matrix. You might choose to work with a copy of the matrix, or you might modify the original and keep track of which positions were changed. Either way, you need to display the cleaned version with the replaced zeros shown in red.

### Task 3: Normalize Matrix Data

Normalization transforms the matrix values into a binary form (zeros and ones). For each digit in the cleaned matrix, you compare it against 5. If the value is less than 5, you replace it with 0. If it is greater than or equal to 5, you replace it with 1.

The key instruction sequence involves loading each character, subtracting '0' to convert from ASCII to a numeric value, comparing against 5 using CMP, and then using conditional jumps to decide which value to store. After deciding, you add '0' back to convert the numeric result back to ASCII before storing or displaying it.

### Task 4: Row Sum Reduction

This task requires summing all elements in each row and displaying the sum at the end of that row. Since your matrix is 7 columns by 4 rows, you will have four sums to calculate. For each row, you initialize a sum to zero, then iterate through all seven elements in that row, adding each value to your running sum.

Since the matrix now contains only '0' and '1' characters, you need to convert from ASCII to numeric by subtracting '0' before adding to your sum. After processing a complete row, you convert the sum back to ASCII for display. If the sum is greater than 9, you will need to handle multiple digits, which requires dividing by 10 to extract each digit.

The row sums should be displayed in green. You will use the same INT 10h function 09h technique, but with attribute byte 0Ah for green text.

### Task 5: Column Sum Reduction

This task is similar to Task 4 but sums vertically instead of horizontally. The challenge is accessing elements by column rather than by row. If your matrix is stored in row-major order (which is typical), then consecutive elements in memory are in the same row. To access a column, you need to skip by the row length each time.

For a 7-column matrix, to move from one row to the next in the same column, you add 7 to your index. You will maintain seven separate sums, one for each column, and display them in yellow (attribute 0Eh) below the matrix.

### Task 6: Horizontal Reflection

Horizontal reflection means flipping the matrix upside down. The first row becomes the last row, the second row becomes the second-to-last row, and so on. For a 4-row matrix, you need to swap row 0 with row 3, and swap row 1 with row 2.

The algorithm involves using two pointers: one starting at the first row and one starting at the last row. You swap the entire rows by exchanging each element, then move the pointers toward each other. When the pointers meet or cross, you are done.

The key instructions include setting up SI to point to the first row and DI to point to the last row, using LODSB to load from the source and STOSB to store to the destination, but you will need to be careful because you are swapping, not just copying. You might need a temporary buffer or register to hold values during the swap.

### Task 7: Vertical Reflection

Vertical reflection flips the matrix left to right. Each row is reversed independently. For a 7-column row, the first element swaps with the seventh, the second with the sixth, and the third with the fifth. The middle element (if there is one) stays in place.

The algorithm is similar to horizontal reflection but works within each row. For each row, set up two pointers, one at the start and one at the end of the row. Swap the elements they point to, move the pointers toward each other, and repeat until they meet.

## Display and Formatting
---
### Getting System Date and Time

Before each task display, you need to show the current date and time. The BIOS provides this through INT 1Ah. Function 00h returns the tick count since midnight, but that is not very user-friendly. A better approach is to use INT 21h function 2Ah for getting the date and function 2Ch for getting the time.

For the date, INT 21h function 2Ah returns the year in CX, month in DH, day in DL, and day of week in AL. For the time, function 2Ch returns hours in CH, minutes in CL, seconds in DH, and hundredths of seconds in DL. You will need to convert these binary values to ASCII strings for display.

Converting a two-digit number to ASCII requires dividing by 10 to get the tens digit, then using the remainder as the ones digit. The DIV instruction divides AX by the operand, putting the quotient in AL and remainder in AH. After dividing, you add 30h to each digit to convert from binary to ASCII.

### Clearing the Screen

Before displaying each new task, you must clear the screen. The standard way to do this is using INT 10h function 06h with AL set to 00h, which scrolls the entire window. You set CH and CL to 00h for the upper-left corner coordinates, and DH and DL to the maximum row and column for the lower-right corner (typically 24 for rows and 79 for columns).

The attribute byte in BH determines the color of the cleared screen. For a black background, use 00h. This effectively fills the screen with spaces in the specified color.

### Cursor Positioning

For precise control over where text appears, you use INT 10h function 02h. This sets the cursor position based on row (DH) and column (DL) coordinates. The upper-left corner is row 0, column 0. You can use this to create structured layouts for your matrix display.

A good strategy is to define constants for where each part of the display should appear. For example, you might put the date and time at row 0, the task title at row 2, and the matrix starting at row 4.

## Memory Organization
---
### Matrix Storage

Your matrix is 7 columns by 4 rows, with each element being a single character (one byte). You can store this as a continuous array of 28 bytes in the data segment. To access element at row R and column C, you calculate the offset as: R times 7 plus C.

You might declare your matrix like this in the data segment:
```assembly
matrix DB '9', '7', 'A', '2', '1', '-', '2'
       DB '4', 'M', '8', '2', '6', '3', 'F'
       DB '9', 'B', 'C', '4', '&', '6', '7'
       DB '0', '/', '6', '2', '*', '=', '8'
```

### Working Matrices

Depending on your implementation, you might need multiple copies of the matrix. One approach is to keep the original matrix untouched and work with copies for each processing stage. Another approach is to transform the matrix in place and track what stage of processing you are at.

For the normalization step, you are permanently changing the data, so you might want to preserve the cleaned version before normalizing, or you might regenerate it from the original when needed.

### Task Counter and State

You need to maintain state variables that persist across interrupt handler invocations. These should be stored in the data segment and include at minimum a tick counter, a task counter indicating which task to display next, and a flag indicating whether the main loop should display a task.

The tick counter increments each time INT 1Ch fires and resets when it reaches 546. The task counter increments each time a task is displayed and follows the sequence specified in the project requirements. After the sixteenth task, the program should exit.

## Interrupt Vector Table Manipulation
---
### Reading the Current Vector

The interrupt vector table starts at memory address 0000:0000. Each entry is four bytes: two bytes for the offset (IP) and two bytes for the segment (CS). Entry 1Ch is at offset 1Ch times 4, which equals 70h (112 decimal).

To safely read the current vector, use INT 21h function 35h. You put the interrupt number (1Ch) in AL, and the function returns the segment in ES and offset in BX. You should save these values so you can restore them when your program exits.

### Setting Your Custom Vector

To install your handler, use INT 21h function 25h. You put the interrupt number in AL, the segment of your handler in DS, and the offset in DX. Before calling this function, you should disable interrupts with CLI to prevent an interrupt from firing while the vector is partially changed. After the vector is set, re-enable interrupts with STI.

### Restoring the Original Vector

Good programming practice requires cleaning up before exiting. Before your program terminates, restore the original INT 1Ch vector using INT 21h function 25h again, this time with the saved segment and offset values. This ensures that other programs running after yours will not experience unexpected behavior.

## Modular Programming Approach
---
### Procedure Organization

The project explicitly requires modular code with no redundancy. This means each distinct operation should be its own procedure. You should have procedures for tasks like converting a binary number to ASCII, displaying a string with color, clearing the screen, positioning the cursor, getting the date and time, and of course one procedure for each of the seven tasks.

Each procedure should follow the standard convention of saving any registers it modifies (using PUSH at the start and POP before returning) and using the stack for parameter passing if needed.

### Example Procedure Structure

A typical procedure might look like this:
```assembly
; Procedure: Display colored character
; Input: AL = character, BL = color attribute
; Output: None
; Modifies: AH (but saves it)
DisplayColorChar PROC
    PUSH AX
    PUSH BX
    PUSH CX
    
    MOV AH, 09h        ; Function: write char with attribute
    MOV CX, 1          ; Repeat count (1 character)
    INT 10h
    
    POP CX
    POP BX
    POP AX
    RET
DisplayColorChar ENDP
```

### Avoiding Code Duplication

If you find yourself writing similar code multiple times, extract that code into a procedure. For example, the code to display the matrix appears in every task but with different data. You should write one general display procedure that takes parameters indicating what data to display and what colors to use.

Similarly, the code to convert numbers to ASCII appears in multiple contexts. Write one procedure that handles this conversion and call it whenever needed.

## Key Assembly Instructions Summary
---
### Data Movement
- **MOV** - Move data between registers or memory
- **LODSB** - Load byte from [SI] into AL, increment SI
- **STOSB** - Store AL into [DI], increment DI
- **LEA** - Load effective address

### Arithmetic
- **ADD** - Add values
- **SUB** - Subtract values
- **INC** - Increment by one
- **DEC** - Decrement by one
- **MUL** - Unsigned multiply
- **DIV** - Unsigned divide (quotient in AL, remainder in AH)

### Comparison and Jumps
- **CMP** - Compare two values (sets flags)
- **JE/JZ** - Jump if equal/zero
- **JNE/JNZ** - Jump if not equal/not zero
- **JL/JNGE** - Jump if less than
- **JG/JNLE** - Jump if greater than
- **JLE/JNG** - Jump if less than or equal
- **JGE/JNL** - Jump if greater than or equal

### Stack Operations
- **PUSH** - Push onto stack
- **POP** - Pop from stack

### Interrupt Control
- **CLI** - Clear interrupt flag (disable interrupts)
- **STI** - Set interrupt flag (enable interrupts)
- **INT** - Call software interrupt
- **IRET** - Return from interrupt

### Loop Control
- **LOOP** - Decrement CX and jump if not zero
- **JMP** - Unconditional jump

## Critical BIOS/DOS Interrupts
---
### INT 10h - Video Services
- **Function 00h** - Set video mode (AL = mode)
- **Function 02h** - Set cursor position (DH = row, DL = column)
- **Function 06h** - Scroll window up/clear screen
- **Function 09h** - Write character and attribute (AL = char, BL = attribute, CX = count)
- **Function 0Eh** - Write character in TTY mode

### INT 21h - DOS Services
- **Function 2Ah** - Get system date (CX = year, DH = month, DL = day)
- **Function 2Ch** - Get system time (CH = hours, CL = minutes, DH = seconds)
- **Function 25h** - Set interrupt vector (AL = interrupt number, DS:DX = handler address)
- **Function 35h** - Get interrupt vector (AL = interrupt number, returns ES:BX)
- **Function 4Ch** - Exit program (AL = return code)

### INT 1Ch - Timer Tick Interrupt
- **No functions** - This is called automatically by INT 08h
- Fires 18.2 times per second
- Default handler does nothing (just IRET)
- Perfect for hijacking for custom timing

## Execution Flow Diagram
---
The overall program flow follows this pattern:

1. **Initialization Phase**
   - Set up data segment
   - Initialize matrix
   - Save old INT 1Ch vector
   - Install custom INT 1Ch handler
   - Initialize task counter to 0
   - Initialize tick counter to 0

2. **Main Loop**
   - Check if task flag is set
   - If flag set:
     - Call appropriate task procedure based on task counter
     - Increment task counter
     - If task counter reaches 16, exit
     - Clear task flag
   - Loop forever (or until done)

3. **Interrupt Handler (fires every 55ms)**
   - Increment tick counter
   - If tick counter >= 546:
     - Set task flag
     - Reset tick counter to 0
   - IRET (return from interrupt)

4. **Cleanup Phase**
   - Restore old INT 1Ch vector
   - Exit program cleanly

## Task Sequence Management
---
The project specifies this exact sequence:
- Tasks 1-5 (Lesson 1, first time)
- Tasks 1-5 (Lesson 1, second time)
- Tasks 6-7, 6-7, 6-7 (Lesson 2, three times)

One elegant way to implement this is with a lookup table. Create an array containing the sequence [1, 2, 3, 4, 5, 1, 2, 3, 4, 5, 6, 7, 6, 7, 6, 7]. When a task needs to be displayed, index into this array based on your task counter.

Alternatively, use conditional logic based on the task counter value. If the counter is 0-4, call task (counter + 1). If counter is 5-9, call task (counter - 4). If counter is 10 or higher, calculate which instance of tasks 6-7 to display.

## Testing Strategy
---
As you develop each piece, test it individually. Write a small test program that just displays the matrix, or just cleans it, or just counts to 30 seconds. Only after each component works in isolation should you integrate them into the full program.

For the interrupt handler, a good debugging technique is to make it do something simple and visible, like incrementing a counter displayed on screen. This confirms that your handler is being called and that you have correctly installed it in the IVT.

## Common Pitfalls
---
One frequent mistake is forgetting to preserve registers in procedures or interrupt handlers. If your interrupt handler modifies AX without saving it, and the main program was using AX when the interrupt fired, the main program will find a corrupted value when it resumes. Always push and pop any registers you modify.

Another common error is incorrect calculations for matrix element access. Remember that for a 7-column matrix, element at row R, column C is at offset (R times 7 plus C). Off-by-one errors here will cause you to access the wrong elements or even memory outside the matrix.

Be careful with the direction flag when using string instructions like LODSB and STOSB. The CLD instruction clears the direction flag, making these instructions increment the index registers. If the direction flag is set (STD), they decrement instead, which is rarely what you want.

## Optimization Considerations
---
While the project asks for optimized code, clarity should take priority over micro-optimizations. The most important optimization is eliminating redundant code through good use of procedures. Avoid copy-pasting similar code blocks.

For performance, minimize work done in the interrupt handler. The handler should run as quickly as possible because it interrupts whatever else the CPU was doing. Do only the essential tick counting in the handler and defer all display work to the main program loop.

## The Bonus Extension
---
The bonus question asks for creative use of INT 1Ch beyond the base requirements. Some ideas include allowing the user to press a key to pause or resume the automatic progression, varying the time interval between tasks based on their complexity, or adding a new lesson with additional matrix operations.

You might implement a countdown timer showing seconds remaining until the next task. Or you could track how long the program has been running and display that information. The key is to demonstrate that you understand the interrupt mechanism well enough to adapt it creatively.

## Final Thoughts
---
This project teaches you fundamental concepts that apply far beyond assembly programming. Interrupt-driven programming is how modern operating systems work. The timer interrupt allows the OS to give each program a time slice, creating the illusion that multiple programs run simultaneously.

By hijacking INT 1Ch, you are essentially creating a simple task scheduler. Your program manages state, tracks time, and triggers actions at specific intervals. These are the building blocks of cooperative multitasking systems.

Take your time to understand each piece before moving to the next. Assembly language forces you to think about every single instruction, which develops a deep understanding of how computers actually work at the hardware level. This knowledge will serve you well even when programming in higher-level languages.
