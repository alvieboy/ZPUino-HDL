For this bootloader variant it is important to change the ../../../../bootloader/boot.cpp file so that the timeout is 3 seconds instead of 1 second. Change the following line:
# define BOOTLOADER_WAIT_MILLIS 1000
to
# define BOOTLOADER_WAIT_MILLIS 3000