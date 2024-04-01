from pathlib import Path
import glob
import os
import pandas as pd
import shutil
import subprocess 
import sys
import tarfile
import textgrids

pd.options.display.max_colwidth = 500

def call_all(codes_csv, params_xlsx, sound_times_csv, sst_csv, trans_csv, sss_csv, tmp_csv):

    #it would be more efficient to pass the data from one module to the other without writing to files, but this modularity allows validation of intermediate steps
    
    st_nm = Path(sound_times_csv).stem
    st_path = Path(sound_times_csv).parent
    sound_times1_csv = str(st_path) + '\\' + st_nm + '1.csv'
    sound_times2_csv = str(st_path) + '\\' + st_nm + '2.csv'

    trans_nm = Path(trans_csv).stem
    trans_path = Path(trans_csv).parent
    trans1_csv = str(trans_path) + '\\' + trans_nm + '1.csv'
    trans2_csv = str(trans_path) + '\\' + trans_nm + '2.csv'

    sst_nm = Path(sst_csv).stem
    sst_path = Path(sst_csv).parent
    sst1_csv = str(sst_path) + '\\' + sst_nm + '1.csv'
    sst2_csv = str(sst_path) + '\\' + sst_nm + '2.csv'
    
    sss_nm = Path(sss_csv).stem
    sss_path = Path(sss_csv).parent
    sss1_csv = str(sss_path) + '\\' + sss_nm + '1.csv'
    sss2_csv = str(sss_path) + '\\' + sss_nm + '2.csv'
    
    #create sound/silence textgrids for each file in the corpora, for each of the parameters specified
    call_praat(codes_csv, params_xlsx)
    #pull the sound times from the Praat textgrids into sound_times_csv
    textgrids_to_csv(codes_csv, params_xlsx, sound_times_csv, sound_times1_csv, sound_times2_csv, ltnc_csv)
    #analyze the sound times for transitions and create files for the turn times on each channel (sst_csv) and for transitions (trans_csv)
    #it would be more efficient to add the latency-adjusted times as separate columns, but this way I can just re-use the code I've already written
    find_turn_begin(sound_times_csv, sst_csv, trans_csv)
    find_turn_begin(sound_times1_csv, sst1_csv, trans1_csv)
    find_turn_begin(sound_times2_csv, sst2_csv, trans2_csv)
    #create textgrids of transitions to help explain the data
    trans_textgrids(codes_csv, trans_csv, sss_csv, tmp_csv, 0)
    trans_textgrids(codes_csv, trans1_csv, sss1_csv, tmp_csv, 1)
    trans_textgrids(codes_csv, trans2_csv, sss2_csv, tmp_csv, 2)


def make_tarfile(output_filename, source_dir):
    with tarfile.open(output_filename, "w:gz") as tar:
        tar.add(source_dir, arcname=os.path.basename(source_dir))

def call_praat(codes_csv, params_xlsx):

    dtypes = {'Corpus': str, 'Language': str, 'Description': str, 'LangCd': str, 'RegionLangCd': str, 'Mode': str, 'Designation': str, 'Code': str, 'wavDir': str, 'TextGridDir': str, 'PitchDir': str}
    codes = pd.read_csv(codes_csv,dtype=dtypes)

    params = pd.read_excel(params_xlsx)

    praat = r'C:\Program Files\praat\praat.exe'
    parm1 = '--run'
    pr_scr = 'silences-param.praat'
    for codes_ix, code_row in codes.iterrows():
        print(code_row.Code)
        if code_row.Corpus == 'CGN':
            if code_row.RegionLangCd == 'nl':
                trunc = 2
            else:
                trunc = 1
        else:
            trunc = 0
        for parm_ix, parm_row in params.iterrows():
            out_dir = code_row.TextGridDir + parm_row.folder 
            if not os.path.exists(out_dir):
                os.makedirs(out_dir)
            #out_dir = '"' + out_dir + '"'
            #wav_dir = '"' + code_row.wavDir + '"'
            wav_dir = code_row.wavDir
      
            subprocess.run([praat, parm1, pr_scr, wav_dir, out_dir, str(trunc), str(parm_row.sound), str(parm_row.silence), str(parm_row.ints)],shell=True)
            prnt = str(Path(out_dir).parent)
            tar_name = prnt + '\\' + code_row.Code + parm_row.folder + '.tar.gz'
            make_tarfile(tar_name,out_dir)
            #shutil.rmtree(out_dir)   
            
def textgrids_to_csv(codes_csv, params_xlsx, sound_times_csv, sound_times1_csv, sound_times2_csv, ltnc_csv):
    codes = pd.read_csv(codes_csv)
    params = pd.read_excel(params_xlsx)    
    ltnc = pd.read_csv(ltnc_csv,index_col=1).transpose().to_dict('series')   

    with open(sound_times_csv, 'w') as outfile, open(sound_times1_csv, 'w') as outfile1, open(sound_times2_csv, 'w') as outfile2:
        out_str = 'subcorpus,params,conv,ch,begin,end\n'
        outfile.write(out_str) 
        outfile1.write(out_str)
        outfile2.write(out_str)
        
        for code_index, code_row in codes.iterrows():
            
            for parm_ix, parm_row in params.iterrows():
                 print(code_row.TextGridDir + parm_row.folder)
                 TextGridDir = os.fsencode(code_row.TextGridDir + parm_row.folder) 
                 if os.path.exists(TextGridDir):
                    for file in os.listdir(TextGridDir):
                        #convert from bytes to string
                        s_file = file.decode('windows-1252')
                        if s_file.find('both') == -1 and s_file.find('TextGrid') != -1:
                            i = s_file.find('_')
                            if i < 2:
                                conv_nm = s_file[i-1:i]
                                ch = s_file[i+3:i+4]
                            else:
                                conv_nm = s_file[i-2:i]
                                ch = s_file[i+3:i+4]    
                            ltnc_s = ltnc[int(conv_nm)][1] / 1000000
                            ltnc_start = float(ltnc[int(conv_nm)][2])
                            ltnc_end = float(ltnc[int(conv_nm)][5])
                            #print(str(ltnc_start))
                            #print(str(ltnc_end)) 
                                        
                            grid = textgrids.TextGrid(TextGridDir + b'\\' + file)
                            for per in grid['silences']:
                                label = per.text.transcode()
                                begin_sound = str(round(per.xmin,8))
                                end_sound = str(round(per.xmax,8))
                                if label == 'sounding':
                                    out_str = code_row.Code + "," + parm_row.folder + "," + conv_nm + ',' + ch + ',' + begin_sound + ',' + end_sound + '\n'
                                    outfile.write(out_str)            
                                    if per.xmin >= ltnc_start and per.xmax < ltnc_end:
                                        begin_sound = str(round(per.xmin - ltnc_s,8))
                                        end_sound = str(round(per.xmax - ltnc_s,8))
                                        out_str_ch = code_row.Code + "," + parm_row.folder + "," + conv_nm + ',' + ch + ',' + begin_sound + ',' + end_sound + '\n'
                                    else:
                                        out_str_ch = out_str
                                    if ch == '1':
                                        #from perspective of ch 1
                                        outfile1.write(out_str_ch)
                                        outfile2.write(out_str)
                                    else:
                                        #from perspective of ch 2
                                        outfile2.write(out_str_ch)
                                        outfile1.write(out_str)
                                        
def find_turn_begin(sound_times_csv, sst_csv, trans_csv):
    
    dtypes = {'subcorpus': str, 'params': str, 'conv': str, 'ch': int, 'begin': float, 'end': float}
    df = pd.read_csv(sound_times_csv,dtype=dtypes, low_memory=False)
    
    #for testing
    #df = df.loc[df['conv'] == '4156']
    
    df.sort_values(by=['subcorpus','params','conv', 'begin'], inplace=True)

    last_subcorp = ' '
    last_params = ' '
    last_conv = ' '
    begin_turn =[0,0]
    last_end   =[0,0]
      
    with open(sst_csv, 'w') as turn_file, open(trans_csv, 'w') as trans_file:
        #header
        turn_str = 'subcorpus,params,conv,ch,begin_sound,end_sound,begin_turn\n'
        turn_file.write(turn_str)
        
        trans_str = 'subcorpus,params,conv,ch,begin_sound,end_sound,begin_turn,gap,debug\n'
        trans_file.write(trans_str)
        
        for index, row in df.iterrows():
            continuation = False
            #if this is a new conversation
            if not(row.conv == last_conv and row.subcorpus == last_subcorp and row.params == last_params):
                #print(row.subcorpus + " " + row.params + " " + str(row.conv))
                begin_turn[0]=0
                begin_turn[1]=0
                last_end[0]=0
                last_end[1]=0
                first = True
                
            #convert to zero-based channel number
            row.ch = row.ch - 1
            if row.ch == 0:
                oth_ch = 1
            else:
                oth_ch = 0
            #if this is the first row for this channel 
            if last_end[row.ch] == 0:
                #then set begin_turn
                begin_turn[int(row.ch)] = row.begin 
            else:
                #if the last from the other channel is after the last end of this channel   
                if last_end[oth_ch] >= last_end[row.ch]:   
                    #then reset begin_turn
                    begin_turn[int(row.ch)] = row.begin
            turn_str = row.subcorpus + ',' + row.params + ',' + str(row.conv) + ',' + str(row.ch) + ',' + str(round(row.begin,8)) + ',' + str(round(row.end,8)) + ',' + str(round(begin_turn[int(row.ch)],8)) + '\n'
            turn_file.write(turn_str)
            
            debug_cd = 'a'
            if not(first):
                if last_end[oth_ch] > row.begin:
                    if last_end[oth_ch] > row.end:
                        #fully contained
                        gap = row.begin - row.end
                        debug_cd = 'b'
                    else:
                        gap = row.begin - last_end[oth_ch]
                        if last_end[oth_ch] == row.end:
                            #both sides end together
                            debug_cd = 'm'
                        else:
                            #dovetail
                            debug_cd = 'd'
                else:
                    if last_end[oth_ch] >= last_end[row.ch]:
                        #positive gap
                        gap = row.begin - last_end[oth_ch]
                        if last_end[oth_ch] == last_end[row.ch]:
                            debug_cd = 'k'
                        else:
                            debug_cd = 'h'
                    else:
                        continuation = True
                        gap = 0
                        debug_cd = 'e'
          
                if not(continuation) and not(first):
                    trans_str = row.subcorpus + ',' + row.params + ',' + str(row.conv) + ',' + str(row.ch) + ',' + str(round(row.begin,8)) + ',' + str(round(row.end,8)) + ',' + str(round(begin_turn[int(row.ch)],8)) + ',' + str(round(gap,8)) + ',' + debug_cd + '\n'
                    trans_file.write(trans_str)
            
            last_end[int(row.ch)]=row.end
            last_conv = row.conv
            last_subcorp = row.subcorpus
            last_params = row.params
            first = False


def trans_textgrids(codes_csv, trans_csv, sss_csv, tmp_csv, ch):

    codes = pd.read_csv(codes_csv)
    dtypes = {'subcorpus': str,'params': str, 'conv': str, 'ch': int, 'begin_sound': float, 'end_sound': float, 'begin_turn': float, 'gap': float, 'debug': str}
    df = pd.read_csv(trans_csv,dtype=dtypes, low_memory=False, header = 0)
    #print(df)

    with open(sss_csv, 'w') as sss_file:
        sss_str = 'subcorpus,params,conv,ch,begin,end\n'
        sss_file.write(sss_str)
    
    for row, value in df.groupby(['subcorpus','params','conv']).indices.items():
        subcorpus = row[0]
        params=row[1]
        conv=row[2]
        dir = (codes.loc[codes['Code'] == subcorpus]["TextGridDir"].to_string(index=False, header=False)) + params
        dfconv = df.loc[value]
        create_conv_textgrid(dfconv, conv, dir, tmp_csv, sss_csv, params, ch)
        
def create_conv_textgrid(df, conv, dir, tmp_csv, sss_csv, params, ch):
    grid = textgrids.TextGrid()

    trans = []
    prev_beg = 0
    prev_end = 0
    prev_overlap = 0
    
    with open(sss_csv, 'a') as sss_file:

        #if gap > 0 then subtract it from begin_turn to get beginning of gap, else if overlap we subtract it to get the end
        #we have to end the previous turn before we log the gap/overlap (if there is one)
        for index, row in df.iterrows():
            
            if row['gap'] > 0:
                #don't write record if begin == end
                if round(prev_beg - prev_overlap,4) != round(row['begin_turn'] - row['gap'],4):
                    beg_seg = round(prev_beg - prev_overlap,4)
                    end_seg = round(row['begin_turn'] - row['gap'],4)
                    trans.append(['single speaker',beg_seg,end_seg])
                    sss_str = row.subcorpus + ',' + row.params + ',' + str(row.conv) + ',' + str(int(not(row.ch))) + ',' + str(beg_seg) + ',' + str(end_seg) + '\n'
                    sss_file.write(sss_str)
            
                trans.append(['gap',round(row['begin_turn'] - row['gap'],4),round(row['begin_turn'],4)])  
                prev_overlap = 0
            elif row['gap'] == 0: 
                beg_seg = round(prev_beg - prev_overlap,4)
                end_seg = round(row['begin_turn'],4)
                trans.append(['single speaker',beg_seg,end_seg])
                sss_str = row.subcorpus + ',' + row.params + ',' + str(row.conv) + ',' + str(int(not(row.ch))) + ',' + str(beg_seg) + ',' + str(end_seg) + '\n'
                sss_file.write(sss_str)
                prev_overlap = 0
            else:
                #don't write record if begin == end
                if round(prev_beg - prev_overlap,4) != round(row['begin_turn'],4):
                    beg_seg = round(prev_beg - prev_overlap,4)
                    end_seg = round(row['begin_turn'],4)
                    trans.append(['single speaker',beg_seg,end_seg])
                    sss_str = row.subcorpus + ',' + row.params + ',' + str(row.conv) + ',' + str(int(not(row.ch))) + ',' + str(beg_seg) + ',' + str(end_seg) + '\n'
                    sss_file.write(sss_str)
                trans.append(['overlap',round(row['begin_turn'],4),round(row['begin_turn'] - row['gap'],4) ])
                prev_overlap = row['gap']
       
            prev_beg = row['begin_turn']
            prev_end = row['end_sound']
        
    newdf = pd.DataFrame(trans)
    #shouldn't have to write newdf to a file, but I don't see a textgrids method to process a list
    
    newdf.to_csv(tmp_csv,index=0,header=0,sep=';')
    
    tier_name = 'transitions'
    grid.tier_from_csv(tier_name,tmp_csv)

    grid.xmax = newdf[2].max()
    
    if ch == 0:
        tg_nm = dir + '\\' + conv + params + '_trans.Textgrid'
    elif ch == 1:
        tg_nm = dir + '\\' + conv + params + '1_trans.Textgrid'
    else:
        tg_nm = dir + '\\' + conv + params + '2_trans.Textgrid'
    #print(tg_nm)
    grid.write(tg_nm) 
            
if __name__ == '__main__':
    #maybe come back and redo this with argparse to allow named parameters
    
    #defaults:
    codes_csv = 'c:\\temp\\codes.csv'
    params_xlsx = 'c:\\temp\\params.xlsx'
    sound_times_csv = 'c:\\temp\\sound_times.csv'
    sst_csv = 'c:\\temp\\sound_silence_turn.csv'
    trans_csv = 'c:\\temp\\trans.csv'
    sss_csv = 'c:\\temp\\sss.csv'
    tmp_csv = 'c:\\temp\\create_tier_tmp.csv'
    #
    nump = len(sys.argv)
    if nump >= 2:
        codes_csv = sys.argv[1]
    if nump >= 3:
        params_xlsx = sys.argv[2]
    if nump >= 4:
        sound_times_csv = sys.argv[3]
    if nump >= 5:
        sst_csv = sys.argv[4]
    if nump >= 6:
        trans_csv = sys.argv[5]
    if nump >= 7:
        sss_csv = sys.argv[6]
    if nump >= 8:
        ltnc_csv = sys.argv[7]
    if nump >= 9:
        tmp_csv = sys.argv[8]
    print('codes:' + codes_csv)
    print('params:' + params_xlsx)
    print('st:' + sound_times_csv)
    print('sst:' + sst_csv)
    print('trans:' + trans_csv)
    print('sss:' + sss_csv)
    print('ltnc:' + ltnc_csv)
    print('tmp:' +tmp_csv)
    
    call_all(codes_csv, params_xlsx, sound_times_csv, sst_csv, trans_csv, sss_csv, tmp_csv)