+-------------------------------------------------------------------------------
| INTRODUCTION / ACKNOWLEDGMENTS
+-------------------------------------------------------------------------------

This project started after seeing the HybridSID project by Markus Gritsch
[http://dangerousprototypes.com/forum/viewtopic.php?f=56&t=2197]

Markus is using a real SID chip [http://en.wikipedia.org/wiki/MOS_Technology_SID]
which is driven by a microcontoller to produce the sounds, however I've never
owned a C64 computer back in the day and I don't have access to a real SID
sound chip.

I do however have my trusty Papilio One FPGA board [http://papilio.cc]. Since
an FPGA can be programmed to simulate any kind of hardware, this should not be
a problem.

I also knew absolutely nothing about the inner workings of the SID, or the
scene surrounding it, so the first step was to see if this has already been
done. Sure enough Google returns a bunch of results about SID and FPGA.

The two most notable projects that I could find are:

* Kevin Horton's FPGA SID [http://blog.kevtris.org/?cat=7]
Kevin has designed and built a SID chip based on an Altera FPGA with external
hardware filters. Very nice project and he has spent a lot of time and effort
on it. No source code was released however.

* PhoenixSID 65x81 [http://www.myhdl.org/doku.php/projects:phoenixsid_65x81]
Another great project by George Pantazopoulos to bring a SID to life, this time
using a Xilinx FPGA. Unfortunately George was met with a far too untimely demise
in the prime of his youth. The project has therefore stalled since '06 and no
source code was released.

Not really wanting to reinvent the wheel, I persevered and found a SID written
in VHDL at "Programmable Arcade Circuit Emulation" PACEDev.net
[https://svn.pacedev.net/repos/pace/sw/src/component/sound/sid]

This VHDL SID seems very well written but contains no attribution so the author
is unfortunately unknown. Filters are not implemented here either.

This VHDL code seems to have been written based on information from an interview
with the creator of the SID chip, Bob Yannes [http://www.joogn.de/sid.yannes.html]

+-------------------------------------------------------------------------------
| QUICK START
+-------------------------------------------------------------------------------

At the very minimum you need to own an FPGA platform (this is specifically written
for the Papilio board) and do the following steps:

* Download Xilinx ISE Web Pack (free registration required, 4Gb download!)
[http://www.xilinx.com/support/download/index.htm]

* Download Active Python 2.7
[http://www.activestate.com/activepython/downloads]
This is recommended instead of the python.org download because ActiveState have
packaged some other required utilities such as PySerial in their distribution.

* Download ACID 64 player
[http://www.acid64.com/]

* Download High Voltage SID Collection (or any other source of .sid files)
[http://www.hvsc.c64.org/#download]

* Download Papilio Loader
[http://papilio.cc/index.php?n=Papilio.Download]

Install Xilinx ISE, ActivePython and ACID 64, extract Papilio loader and
the source code for NetSID somewhere. Put some .sid files in the ACID64 dir.

In the build directory run NetSID.xise, Xilinx ISE will start up. The first
thing you need to do is open papilio.ucf and look at the uncommented lines,
make sure they match you FPGA target, and the pins defined there match the
wings you have plugged in. You only have to worry about the LED, NRESET and
the two AUDIO L/R pins, the others are always fixed on the Papilio.

Select the top level module and click "Generate Programming File", the process
will take a couple of minutes and a netsid.bit file should be generated in the
build directory.

Upload it to the Papilio board with the Papilio Loader, eg command line:
butterfly_prog.exe -f netsid.bit

Connect speakers or an amp to the Papilio audio wing.

Run the python script "server_v2_HybridSID - handshake.py" in the top directory.
This python script was borrowed and adapted from Markus Gritsch HybridSID project

You should see something like this, if not, edit the COMPORT at the top of the
python file to match where your Papilio appears when connected.

    using COM16
    listening on port 6581

Run ACID 64 and double click any song to play it, the python script output should
scroll by with lots of status info, hopefully music should be heard :)

+-------------------------------------------------------------------------------
| OPERATION
+-------------------------------------------------------------------------------
The top module connects a number of components together then implements the
necessary glue logic and state machines to drive them.

Again, in the spirit of not re-inventing the wheel, I chose a ready made RS232
UART from a Xilinx design. There seem to be many examples out there of UARTs so
if you don't like this one, pick another. Both the TX and RX sides are used.

The clock module includes a DCM however in this design I'm not really using the
advanced clock synthesis features of it. It's there if you need it though. The
clock in this design is simply taking the 32Mhz system clock and running it
through a counter to obtain a number of divided-by-two clocks with 50% duty cycle.

Only 1Mhz, 4Mhz and 32Mhz are used here. The 1Mhz clock drives the internal SID
sound generation components, the 4Mhz clock drives the state machine that writes
data from the FIFO to the SID. The 32Mhz clock drives mainly the D/A converter
and a few of the faster glue logic, FIFO, etc.

The design can be split into two logical parts that run asynchronously to each
other, the receive side uart_to_ram process (receives data and stores it in the
FIFO) and the transmit side ram_to_sid process (reads data from FIFO and writes
it to the SID). These two sides are connected via a FIFO constructed from dual
ported RAMB.

The UART speed chosen in this design is 2000000 baud 8 bits 1 stop no parity.
Initially I had tried 38400, then later moved to 115200, however some of the
.sid files that contain samples use the volume register of the SID to modulate
the output in real time to create effects such as speech or play back complex
sampled sounds. As such the data rate of those songs far exceeds 115200 baud.
I found 2M baud to be a good value to keep up with high bandwidth sampled
sounds as well as being easily obtained from the current clocks on the board.
In fact it is a requirement of the UART that it be provided with a clock that
is 16 times the expected baud, so the 32M system clock fits the bill perfectly.

As data arrives into the UART at 2M baud it generates a pulse on rx_data_present
for each byte received. This is used to clock the receved data byte into the FIFO
buffer. The stream of data ariving at the UART consists of 4 byte packets, the
first two bytes specify a delay (big endian) then a register and a value to be
written at that register after the specified delay (in 1Mhz cycles).

For example, receiving 00 08 01 4A means:
Wait eight 1Mhz clock cycles (8us) then write 4A to register 01.

There is no packet header to keep the data synchronized! This doesn't cause any
issues in practice however it's possible that data may become unsynched. The
only way to recover from that is to stop the data stream and reset the board.

As data is written into the FIFO the write pointer is compared with the read
pointer (address). The read pointer can not overtake (exceed) the write pointer
and will block (wait). This means that if your data arrives through the UART
slower than it plays out, the FIFO will empty and the playback rate will be the
same as the data input rate (rather than the cycle accurate rate specified in
the packets). Your songs will play slower than normal and at an uneven rate.
This shouldn't ever happen in practice given the 2M baud input rate but deals
with the perfectly normal condition of stopping the music playback. When no
more data arrives via the serial, the read pointer will continue to increment
(play music) until it reaches the write pointer (FIFO empty condition) and
become jammed at it (music stops playing). If more data starts streaming into
the UART and at a fater rate than it plays back at, the FIFO will fill up again
incrementing the write pointer, therefore freeing the read pointer to also move
up (play more music).

On the other side of the machine we have a process that reads data from the FIFO
and writes it to the SID. This is driven by a state machine in order to read
the 4 bytes in each packet, interpret them, wait the necessary number of cycles
then write the data to the register and generate the appropriate signals to the
SID chip.

This process runs at 4Mhz so the delay value received is shifted up by two bits
(multiplied by 4) to account for this. It will continue to move data from the
FIFO to the SID as long as the FIFO is not empty.

So we now have a process that receives data and writes to the FIFO at a certain
rate and another process that takes data from the FIFO and writes to the SID at
a different rate. We need to implement some sort of logic that keeps these two
in check so the we're not writing data onto the FIFO when it is full, therefore
overwriting previous data but also we don't want to read from the FIFO when it
is empty, therefore replaying previously played data. Both of these conditions
are bad and result in mangled music playback.

Process fifo_handshake implements this handshaking by generating the buf_full
signal and also loading the TX side of the UART with the correct byte semafore
to send, "E" meaning End transmission and "S" meaning Start transmission. The
python script obeys those commands and will pause (End) transmission of serial
data until it receives a resume (Start) signal.

There is also some hysteresis implemented in the theresholds generating the
buf_full signal. It will rise (buffer full) when the FIFO is 3/4 full and fall
(buffer empty) when the FIFO is 1/4 full.

Due to the limited number of address bits the statement (ram_ai - ram_ao) really
implements the equivalent of ABS(ram_ai - ram_ao) so the theresholds are still
valid as the pointers reach their maximum value and roll over through zero.

We only have one more thing to do to complete this infernal machine, we have to
actually send the handshake semafore bytes loaded on the UART data bus by the
fifo_handshake process.

In order to do that we have two problems. We need to trigger the UART send on
both the rising and the falling edge of the buf_full signal. We also need to
generate a write_to_uart signal that is exactly one 32Mhz clock cycle long and
not longer. If that signal was longer, then a byte would the sent out of the
UART for every 32Mhz clock cycle that write_to_uart is held high.

Tackling the first problem, since we can't trigger events on both the rising
and falling of the same signal inside a process (it won't synthesize), we
implement the detect_edges process that generates two signals, buf_full_re
and buf_full_fe (rising edge and falling edge of buf_full). These signals
pulse high briefly every time buf_full meets the relevant condition, rises
or falls.

These are then used in the uart_fifo_tx process to initialize a state machine
running in process uart_fifo_we that has only one job to do. Generate the signal
write_to_uart that is high for exaclty one 32Mhz clock cycle.

+-------------------------------------------------------------------------------
| IMPROVEMENTS / NEXT STEPS / IDEAS?
+-------------------------------------------------------------------------------
This is really something I threw together with very little efffort in a matter of
days, consider it an initial starting point. Feel free to study it and improve it.
If you don't like something, change it to suit you.

The first thing that comes to mind is that no one has implemented filters in a
SID HDL. The other two projects mentioned above chose to construct filters in
real hardware with analog components.

I highly recommend reading this excellent page on FIR filters, which really
opened my eyes: [http://www.labbookpages.co.uk/audio/firWindowing.html]

That page is by far the easiest to comprehend FIR filter design page I have
ever come across and I now have a very good understanding of how FIR filters
work and how to construct them. Given the formulas on that page it took me mere
minutes to put together an Excel spreadsheet to calculate the filter coefficients
for any number of taps FIR filter. I do intend, time permitting, to implement
a FIR filter in VHDL and run some tests through it. Perhaps, all going well,
implement filters in this SID.

Secondly, the current buffer in the FPGA is not really optimal. For example,
some .sid files have very low throughput, as such, when they fill the buffer
there is enough data there to keep playing for a number of seconds, even if in
the meantime you've clicked on another song, you still have to wait for the
old song data in the buffer to play out before the new song starts playing.
This could be vastly improved by only buffering a certain about of _time_
rather than a certain amount of _samples_
