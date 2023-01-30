import subprocess
import random
import time
import sys
import io

def main():
    numParams =  len(sys.argv) - 1           
    if (numParams > 0):
        print("Starting...")
        conv = sys.argv[1]
        conv_num_file = "/home/de/Private/onedrive/latency/last_conv_num"
        if conv == "next":
            with open(conv_num_file, 'r', encoding='utf-8') as read_file:
                file_data = read_file.readline().rstrip()
                if file_data.isdigit():
                    conv = int(file_data) + 1
                else:
                    print("error in conv file")
                    sys.exit(1)

        if (numParams > 1):
            arg2 = sys.argv[2]
                    
            if arg2.isdigit():
                randomDelay = int(arg2)
            else:
                print("latency value must be an integer")
                sys.exit(1)
        else:        
            random.seed()
            randomDelay = random.randrange(1024,500000)

        with open(conv_num_file, 'w', encoding='utf-8') as write_file:
            write_file.write(str(conv))
        print("Beginning Alsa Capture")
        alsaCapture(str(conv), randomDelay)
    else:
        print("filename required")

def alsaCapture(conv, randomDelay):
    try:
        #values in seconds
        ltncySt=780
        ltncyEnd=1140
        recEnd=1500
        tmpDir   = "/home/de/Private/tmp/"
        oneDrvDir= "/home/de/Private/onedrive/"
        dataDir  = oneDrvDir + "latency/Data/"
        
        #write delay to file
        convFilename=tmpDir + conv + ".txt"
        with io.open(convFilename, 'w', encoding='utf8') as convFile:
            convFile.write(str(randomDelay) + "\n")
        dev0 = "plughw:CARD=Device"
        dev1 = "plughw:CARD=Device_1" 
        
        beep_file = oneDrvDir + "latency/misc/ringtonehalf.wav"
        #klugey ringtone - ideally would be played on both devices simultaneously
        play_beep(beep_file, dev0, dev1)
        play_beep(beep_file, dev0, dev1)        
        #time.sleep(0.8)
        #play_beep(beep_file, dev0, dev1)
        #play_beep(beep_file, dev0, dev1)        
        #time.sleep(0.8)
        #play_beep(beep_file, dev0, dev1)                
        #play_beep(beep_file, dev0, dev1)           
        
        #file iteration (a, b, or c)
        iteration = "a"  
        alsaProc(conv, tmpDir, dev0, dev1, iteration, ltncySt, 0)
        
        iteration = "b" 
        alsaProc(conv, tmpDir, dev0, dev1, iteration, ltncyEnd - ltncySt, randomDelay)
        
        iteration = "c" 
        alsaProc(conv, tmpDir, dev0, dev1, iteration, recEnd - ltncyEnd, 0)
        
        play_beep(beep_file, dev0, dev1)        
        play_beep(beep_file, dev0, dev1)        
        play_beep(beep_file, dev0, dev1)        
        ##iterating through a list would be more elegant, but this works
        wavConv(tmpDir, conv, "0", "a")
        wavConv(tmpDir, conv, "0", "b")
        wavConv(tmpDir, conv, "0", "c")
        wavConv(tmpDir, conv, "1", "a")
        wavConv(tmpDir, conv, "1", "b")
        wavConv(tmpDir, conv, "1", "c")
        #
        wava = wavSt(tmpDir, conv, "a")
        wavb = wavSt(tmpDir, conv, "b")
        wavc = wavSt(tmpDir, conv, "c")
        wavout = tmpDir + conv + ".wav"
        destwav = dataDir + conv + ".wav"
        
        #combine files
        cmb = subprocess.run([
                "/usr/bin/sox",
                wava,
                wavb,
                wavc,
                wavout
                ], check = True)
        print(cmb)

        subprocess.run([
                "/usr/bin/cp",  
                wavout,
                dataDir
                ], check = True)
        subprocess.run([
                "/usr/bin/cp",   
                convFilename,
                dataDir
                ], check = True)
        subprocess.run([
                "/usr/bin/gzip",
                destwav
                ], check = True)   
        #onedrive sync
        #onedrive --syncdir /home/de/Private/onedrive --synchronize --upload-only
        x = subprocess.run([
                "/usr/local/bin/onedrive",
                "--syncdir", oneDrvDir,
                "--synchronize",
                "--upload-only"
                ], check = True) 
        #print(x)       
        print("ok")
        return(0)            
    except:
        print("error")
        raise
        #return(1)

def alsaProc(conv, tmpDir, dev0, dev1, itr, sleepTm, ltncy):
    print(itr)
    #alsaProcess0 = subprocess.Popen
    #alsaProcess1 = subprocess.Popen
    alsaProcess0 = spawnAlsa(conv, dev0, dev1, tmpDir, "0", itr, ltncy)
    alsaProcess1 = spawnAlsa(conv, dev1, dev0, tmpDir, "1", itr, ltncy)
    time.sleep(0.01)  
    
    line0 = checkAlsa(alsaProcess0)
    line1 = checkAlsa(alsaProcess1)
         
    if (len(line0) >0 or len(line1) >0):
        print("stopping due to error")
        print(line0)
        print(line1)
        ##attempt to respawn?
        
    else:
        time.sleep(sleepTm)
    
    alsaProcess0.terminate()
    alsaProcess1.terminate()   
    alsaProcess0.wait()
    alsaProcess1.wait()
         
def spawnAlsa(conv, devA, devB, tmpDir, ch, itr, ltncy):
    #mapping device A to speaker B and file A
    teeA = "tee:\'" + devB + "\'," + tmpDir + conv + "_" + ch + itr +".raw,raw"
    print(devA)
    print(devB)
    print(teeA)
    try:
        if (ltncy >= 1024):  
            proc = subprocess.Popen(
                [
                    "/usr/bin/alsaloop",
                    "-C",
                    devA,
                    "-c",
                    "1",
                    "-P",
                    teeA,
                    "-t",
                    str(ltncy)
            ], stderr=subprocess.PIPE
            )
        else: #alsaloop won't accept a -t value < 1024 (always generates a broken pipe), so for zero latency, we don't pass exclude -t
            proc = subprocess.Popen(
                [
                    "/usr/bin/alsaloop",
                    "-C",
                    devA,
                    "-c",
                    "1",
                    "-P",
                    teeA
            ], stderr=subprocess.PIPE
            )
        return(proc)        
    except:
        print(proc)
        
def checkAlsa(proc):
    line = ""
    if proc.poll() != None:
        line = str(proc.stderr.readline())
    return(line)  

def wavConv(tmpDir, conv, ch, itr):
    #convert to wav
    #sox -r 48000 -e signed -b 16 -c 1 -L temp_0a.raw temp_0a.wav
    raw = tmpDir + conv + "_" + ch + itr + ".raw"
    wav = tmpDir + conv + "_" + ch + itr + ".wav"    
    x = subprocess.run([
                "/usr/bin/sox",
                "-r", "48000",
                "-e", "signed",
                "-b", "16",
                "-c", "1",
                "-L",
                raw,
                wav
                ], check = True)
    #print(x)
    return(x)
                
def wavSt(tmpDir, conv, itr):
    #create stereo file of the 2 separate wav files
    #sox -M -c 1 temp_0a.wav -c 1 temp_1a.wav tempa.wav
    wav0 = tmpDir + conv + "_" + "0" + itr + ".wav"
    wav1 = tmpDir + conv + "_" + "1" + itr + ".wav"
    wavout = tmpDir + conv + itr + ".wav"
    x = subprocess.run([
                "/usr/bin/sox",
                "-M",
                "-c", "1",
                wav0,
                wav1,
                wavout
                ], check = True)
    #print(x)
    ##check return code
    return(wavout)

def play_beep(beep_file, devA, devB):
    subprocess.run([
        "/usr/bin/aplay",  
        "-D",
        devA,
        beep_file
        ], check = True)
    subprocess.run([
        "/usr/bin/aplay",  
        "-D",
        devB,
        beep_file
        ], check = True)    

if __name__ == "__main__":
    main()
