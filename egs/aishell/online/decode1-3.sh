#!/bin/bash

root_dir="/.../kaldi-trunk"
base_path=${root_dir}/egs/aishell
online_path=${base_path}/online
s5_path=${base_path}/s5

. ${s5_path}/path.sh || exit 1; # source the path.
bash ${s5_path}/utils/parse_options.sh || exit 1;

audio_path=${online_path}/online-data/audio
scp_path=${online_path}/online-data/require

models_path=${online_path}/online-data/models/tri3a
model_u=${models_path}/final.mdl
words_u=${models_path}/graph/words.txt
hclg_u=${models_path}/graph/HCLG.fst
utt2spk_u=${scp_path}/utt2spk
cmvn_u=${scp_path}/cmvn.scp
feats_u=${scp_path}/feats.scp
result_path=$online_path/result

rm $scp_path/*

find $audio_path -iname "*.wav" > $scp_path/wav.flist

sed -e 's/\.wav//' $scp_path/wav.flist | awk -F '/' '{print $NF}' > $scp_path/utt.list

# 按/分隔取倒数第二个，也就是取wav所在目录的目录名做speaker
# sed -e 's/\.wav//' $scp_path/wav.flist | awk -F '/' '{i=NF-1;printf("%s %s\n",$NF,$i)}' > $scp_path/utt2spk_all
# 
sed -e 's/\.wav//' $scp_path/wav.flist | awk -F '/' '{printf("%s %s\n",$NF,$NF)}' > $scp_path/utt2spk_all

paste -d' ' $scp_path/utt.list $scp_path/wav.flist > $scp_path/wav.scp_all

utils/filter_scp.pl -f 1 $scp_path/utt.list $scp_path/utt2spk_all | sort -u > $scp_path/utt2spk
utils/filter_scp.pl -f 1 $scp_path/utt.list $scp_path/wav.scp_all | sort -u > $scp_path/wav.scp

utils/utt2spk_to_spk2utt.pl $scp_path/utt2spk > $scp_path/spk2utt

echo "scp utt2spk already!"

# sox a1.wav -b 16 aa1.wav
# sox aa1.wav -r 16000 a1.wav
rm -rf $result_path/*
${s5_path}/steps/make_mfcc_pitch.sh --cmd "run.pl" --nj 1 $scp_path $result_path/make_mfcc $result_path/mfcc || exit 1;

echo "extracted!"

${s5_path}/steps/compute_cmvn_stats.sh $scp_path $result_path/make_mfcc $result_path/mfcc || exit 1;
${s5_path}/utils/fix_data_dir.sh $scp_path || exit 1;

echo "prepared!"

gmm-latgen-faster --max-active=7000 --beam=13.0 --lattice-beam=6.0 --acoustic-scale=0.083333 --word-symbol-table=${words_u} ${model_u} ${hclg_u} "ark,s,cs:apply-cmvn  --utt2spk=ark:${utt2spk_u} scp:${cmvn_u} scp:${feats_u} ark:- | splice-feats  ark:- ark:- | transform-feats ${models_path}/final.mat ark:- ark:- |" "ark:|gzip -c >/dev/null"

exit 0;
