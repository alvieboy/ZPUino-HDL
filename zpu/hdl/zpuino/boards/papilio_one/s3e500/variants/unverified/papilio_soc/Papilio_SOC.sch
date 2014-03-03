<?xml version="1.0" encoding="UTF-8"?>
<drawing version="7">
    <attr value="spartan3e" name="DeviceFamilyName">
        <trait delete="all:0" />
        <trait editname="all:0" />
        <trait edittrait="all:0" />
    </attr>
    <netlist>
        <signal name="clk" />
        <signal name="SPI_MISO" />
        <signal name="rxd" />
        <signal name="SPI_SCK" />
        <signal name="SPI_MOSI" />
        <signal name="txd" />
        <signal name="SPI_CS" />
        <signal name="WING_A_temp(15:0)" />
        <signal name="WING_B(15:0)" />
        <signal name="WING_C(15:0)" />
        <signal name="st_dir" />
        <signal name="st_step" />
        <signal name="st_enable" />
        <port polarity="Input" name="clk" />
        <port polarity="Input" name="SPI_MISO" />
        <port polarity="Input" name="rxd" />
        <port polarity="Output" name="SPI_SCK" />
        <port polarity="Output" name="SPI_MOSI" />
        <port polarity="Output" name="txd" />
        <port polarity="BiDirectional" name="SPI_CS" />
        <port polarity="BiDirectional" name="WING_B(15:0)" />
        <port polarity="BiDirectional" name="WING_C(15:0)" />
        <port polarity="Output" name="st_dir" />
        <port polarity="Output" name="st_step" />
        <port polarity="Output" name="st_enable" />
    </netlist>
    <sheet sheetnum="1" width="3520" height="2720">
        <branch name="clk">
            <wire x2="1600" y1="672" y2="672" x1="1568" />
        </branch>
        <iomarker fontsize="28" x="1568" y="672" name="clk" orien="R180" />
        <branch name="SPI_MISO">
            <wire x2="1600" y1="704" y2="704" x1="1568" />
        </branch>
        <iomarker fontsize="28" x="1568" y="704" name="SPI_MISO" orien="R180" />
        <branch name="rxd">
            <wire x2="1600" y1="736" y2="736" x1="1568" />
        </branch>
        <iomarker fontsize="28" x="1568" y="736" name="rxd" orien="R180" />
        <branch name="SPI_SCK">
            <wire x2="2112" y1="672" y2="672" x1="2080" />
        </branch>
        <iomarker fontsize="28" x="2112" y="672" name="SPI_SCK" orien="R0" />
        <branch name="SPI_MOSI">
            <wire x2="2112" y1="736" y2="736" x1="2080" />
        </branch>
        <iomarker fontsize="28" x="2112" y="736" name="SPI_MOSI" orien="R0" />
        <branch name="txd">
            <wire x2="2112" y1="800" y2="800" x1="2080" />
        </branch>
        <iomarker fontsize="28" x="2112" y="800" name="txd" orien="R0" />
        <branch name="SPI_CS">
            <wire x2="2112" y1="832" y2="832" x1="2080" />
        </branch>
        <iomarker fontsize="28" x="2112" y="832" name="SPI_CS" orien="R0" />
        <branch name="WING_A_temp(15:0)">
            <wire x2="2112" y1="864" y2="864" x1="2080" />
        </branch>
        <branch name="WING_B(15:0)">
            <wire x2="2112" y1="928" y2="928" x1="2080" />
        </branch>
        <iomarker fontsize="28" x="2112" y="928" name="WING_B(15:0)" orien="R0" />
        <branch name="WING_C(15:0)">
            <wire x2="2112" y1="992" y2="992" x1="2080" />
        </branch>
        <iomarker fontsize="28" x="2112" y="992" name="WING_C(15:0)" orien="R0" />
        <branch name="st_dir">
            <wire x2="2096" y1="1712" y2="1712" x1="2064" />
        </branch>
        <branch name="st_step">
            <wire x2="2096" y1="1968" y2="1968" x1="2064" />
        </branch>
        <branch name="st_enable">
            <wire x2="2096" y1="2032" y2="2032" x1="2064" />
        </branch>
        <iomarker fontsize="28" x="2096" y="1712" name="st_dir" orien="R0" />
        <iomarker fontsize="28" x="2096" y="1968" name="st_step" orien="R0" />
        <iomarker fontsize="28" x="2096" y="2032" name="st_enable" orien="R0" />
    </sheet>
</drawing>