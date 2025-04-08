#!/usr/bin/env bash
#
#	Horus Binary RTLSDR Helper Script
#
#   Uses rtl_fm to receive a chunk of spectrum, and passes it into horus_demod.
#


# Change directory to the horusdemodlib directory.
# If running as a different user, you will need to change this line
cd /home/pi/horusdemodlib/


# Receive *centre* frequency, in Hz
# Note: The SDR will be tuned to RXBANDWIDTH/2 below this frequency.
RXFREQ=432630000


# RTLSDR Device Selection
# If you want to use a specific RTLSDR, you can change this setting to match the
# device identifier of your SDR (use rtl_test to get a list)
SDR_DEVICE=horus-pcm.local

# Frequency estimator bandwidth. The wider the bandwidth, the more drift and frequency error the modem can tolerate,
# but the higher the chance that the modem will lock on to a strong spurious signal.
# Note: The SDR will be tuned to RXFREQ-RXBANDWIDTH/2, and the estimator set to look at 0-RXBANDWIDTH Hz.
RXBANDWIDTH=10000

# Enable (1) or disable (0) modem statistics output.
# If enabled, modem statistics are written to stats.txt, and can be observed
# during decoding by running: tail -f stats.txt | python fskstats.py
STATS_OUTPUT=1

# Check that the horus_demod decoder has been compiled.
DECODER=./build/src/horus_demod
if [ -f "$DECODER" ]; then
    echo "Found horus_demod."
else
    echo "ERROR - $DECODER does not exist - have you compiled it yet?"
	exit 1
fi

# Check that bc is available on the system path.
if echo "1+1" | bc > /dev/null; then
    echo "Found bc."
else
    echo "ERROR - Cannot find bc - Did you install it?"
	exit 1
fi

# Use a local venv if it exists
VENV_DIR=venv
if [ -d "$VENV_DIR" ]; then
    echo "Entering venv."
    source $VENV_DIR/bin/activate
fi

# Calculate the SDR tuning frequency
SDR_RX_FREQ=$(echo "$RXFREQ - $RXBANDWIDTH/2 - 1000" | bc)

# Calculate the frequency estimator limits
FSK_LOWER=1000
FSK_UPPER=$(echo "$FSK_LOWER + $RXBANDWIDTH" | bc)

echo "Using SDR Centre Frequency: $SDR_RX_FREQ Hz."
echo "Using FSK estimation range: $FSK_LOWER - $FSK_UPPER Hz"

# Start the receive chain.
# Note that we now pass in the SDR centre frequency ($SDR_RX_FREQ) and 'target' signal frequency ($RXFREQ)
# to enable providing additional metadata to Habitat / Sondehub.
#tune --samprate 48000 --mode horus --frequency $SDR_RX_FREQ --mode horus --ssrc $SDR_RX_FREQ --radio $SDR_DEVICE
pcmcat $SDR_DEVICE -s $SDR_RX_FREQ | $DECODER -q --stats=5 -g -m binary --fsk_lower=$FSK_LOWER --fsk_upper=$FSK_UPPER - - | python -m horusdemodlib.uploader --freq_hz $SDR_RX_FREQ --freq_target_hz $RXFREQ $@
