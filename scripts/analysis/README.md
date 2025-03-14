# telecomm-latency/scripts/analysis
Telecommunication latency analysis scripts.

Code related to a lab experiment gathering conversational data under simulated telecommunications latency scenarios.
See also: https://github.com/utastudents/scripts-conversation-acoustic-analysis 

All code created on Windows 11 and provided for reference. Changes will likely be required to run the code on your system.

Script types

    .py    Python(3.11.2) script
    .R     R(4.3.1) script
    
Code

    single_speaker_segments.py  Main module of the analysis scripts. Note that it requires praat-textgrids (https://pypi.org/project/praat-textgrids/)
        Main steps:
            call_praat          create sound/silence textgrids for each file in the corpora, for each of the parameters specified (requires silences-param.praat from scripts-conversation-acoustic-analysis)
            textgrids_to_csv    pull the sound times from the Praat textgrids into sound_times_csv
            find_turn_begin     analyze the sound times for transitions and create files for the turn times on each channel and for transitions 
            trans_textgrids     create textgrids of transitions to help explain the data
        Example call: 
            python single_speaker_segments.py "C:\Users\david\OneDrive - University of Texas at Arlington\latency\codes.csv" "C:\Users\david\OneDrive - University of Texas at Arlington\latency\params.xlsx" "C:\Users\david\OneDrive - University of Texas at Arlington\latency\sound_times.csv" "C:\Users\david\OneDrive - University of Texas at Arlington\latency\sound_silence_turn.csv" "C:\Users\david\OneDrive - University of Texas at Arlington\latency\trans.csv" "C:\Users\david\OneDrive - University of Texas at Arlington\latency\sss.csv" "C:\Users\david\OneDrive - University of Texas at Arlington\latency\ltnc_start_end.csv"
    dataframes.R                create data frames from the various data files
    tests.R                     statistical tests
    graphs, tables.R            graphs and tables

Manually created files

    codes.csv 
        information about subcorpora
        logical PK is Code (col H)
        columns
            Corpus          Corpus name
            Language        Language name
            Description     Subcorpus full description
            LangCd          Language code (ISO 639-3)
            RegionLangCd    LangCd, with an abbreviation for the region, if one is specified
            Mode            Monomodal (phone) or Multimodal (face-to-face)
            Designation     Distinguishing feature (Required only for some corpora)
            Code            Subcorpus code, made up of abbreviation of Corpus + RegionLangCd
            wavDir          Directory where the audio files are located
            TextGridDir     Directory where the text grids will be placed
            PitchDir        Directory where the pitch files will be placed
        
    params.xlsx 
        acoustic parameters to be evaluated
        logical PK is folder (col H) - iteration column is not actually used
        script only uses sheet 1, so you can keep a library of parameters in sheet 2 and just paste some of them into sheet 1 to check results
        columns
            iter        iteration (used just to help distinguish which row is which)
            sound       sound threshold in s
            silence     silence threshold in s
            ints        intency threshold as a ratio
            sound_ms    sound threshold in ms
            sil_ms      silence threshold in ms
            ints_pct    intensity threshold as a percentage
            folder      the concatenation of the above three fields to be appended onto the end of the value of TextGridDir in codes.csv
