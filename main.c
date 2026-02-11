#include<stdint.h>

#define RESETS_RESET *(volatile uint32_t *) (0x4000c000) /* reset controller registers start at a base address of 0x4000c000 and reset starts from 0x0 */
#define RESETS_RESET_DONE *(volatile uint32_t *) (0x4000c008) /* If a bit is set then a reset done signal has been returned by the peripheral */
/* In order to control the default led in the pico which is gpio25 we need to set bits in its control register 
 * The base address is 0x40014000 and the offset of GPIO25_CTRL is 0x0cc*/
#define IO_BANK0_GPIO25_CTRL *(volatile uint32_t *) (0x400140cc)
#define SIO_GPIO25_OE_SET *(volatile uint32_t *) (0xd0000024)
#define SIO_GPIO25_OUT_XOR *(volatile uint32_t *) (0xd000001c)


__attribute__((section(".boot2"))) void main(void){

    /* rp2040 when powered on all the peripherals are in coma stage that is reset is 1, we can do anything
     * Needs to be cleared before using it.
     * 0:24 bits of the RESET register in the addres 0x4000c000 and each bit is assigned to each peripherals 
     * bit 5 is for IO_BANK0 
     */

    (RESETS_RESET) &= ~(1 << 5); /* clears the 5 bit of RESET reg */
    
    /* By default bits of the RESET_DONE is all 0. 
     * If we do a reset for a specific bit of RESET register then once the reset is done it will return a signal.
     * The signal is simple it just set the name bit in the RESET_DONE*/

    while(!(RESETS_RESET_DONE & (1 << 5))); /*Waits untill the reset is done so that we can move further*/
    
    /* We need to tell the function of GPIO25
     * the bit from 0:4 with that we can pass 0 to 31 intergres and 31 is null 
     * functions are from 1 to 9 only
     * 5 is for SIO (Single cyle input and output )
     * a high-speed, low-latency hardware interface designed for direct CPU control of GPIO pins
     */

    IO_BANK0_GPIO25_CTRL = 5;

    /* Now we need to set the output enable for GPIO25 in SIO */

    SIO_GPIO25_OE_SET = (1 << 25); /* Removed the | for atomic operation which means doing the shift in a single instruction */
    
    while(1) {
        for (uint32_t i = 0; i < 100000; ++i) /*Delay*/    {
            /*You have to remember what state the LED is currently in.
             * XOR just inverts whatever the number is 
             */

            SIO_GPIO25_OUT_XOR = (1 << 25);
        }
        
    }
}
