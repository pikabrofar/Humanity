"""Two-pass EBU R128 loudness normalisation of the mixes written by build.py:
mix_full_raw.wav → mix_full.wav at −14 LUFS / −1 dBTP, mix_nomusic_raw.wav → mix_nomusic.wav at −16 LUFS / −1.5 dBTP.
usage: python3 master.py [dir]   (default: this folder)"""
import json, os, subprocess, sys

DIR = sys.argv[1] if len(sys.argv) > 1 else os.path.dirname(os.path.abspath(__file__))

for name, lufs, tp in (('full', -14, -1.0), ('nomusic', -16, -1.5)):
    src, dst = os.path.join(DIR, f'mix_{name}_raw.wav'), os.path.join(DIR, f'mix_{name}.wav')
    f = f'loudnorm=I={lufs}:TP={tp}:LRA=11'
    log = subprocess.run(['ffmpeg', '-hide_banner', '-nostats', '-i', src, '-af', f + ':print_format=json', '-f', 'null', '-'],
                         capture_output=True, text=True, check=True).stderr
    m = json.loads(log[log.rindex('{'):log.rindex('}') + 1])
    # second pass: apply the measured values as one linear gain, so the mix's dynamics are untouched
    f += (f":measured_I={m['input_i']}:measured_TP={m['input_tp']}:measured_LRA={m['input_lra']}"
          f":measured_thresh={m['input_thresh']}:offset={m['target_offset']}:linear=true")
    subprocess.run(['ffmpeg', '-y', '-hide_banner', '-loglevel', 'error', '-i', src, '-af', f, '-ar', '48000', dst], check=True)
    print('wrote', dst)
