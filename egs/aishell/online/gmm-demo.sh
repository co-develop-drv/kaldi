#!/bin/bash

root_dir=`pwd`/../../..

# tri4a tri5a : final.alimdl
# tri1 tri2 tri3a : final.mdl
model_n=tri5a # tri3a
model_s=final.alimdl # final.mdl

base_path=${root_dir}/egs/aishell
online_path=${base_path}/online
s5_path=${base_path}/s5

audio_path=${online_path}/online-data/audio
scp_path=${online_path}/online-data/require

. ${s5_path}/path.sh || exit 1; # source the path.
bash ${s5_path}/utils/parse_options.sh || exit 1;

models_path=${online_path}/online-data/models/${model_n}
model_u=${models_path}/${model_s}
words_u=${models_path}/graph/words.txt
hclg_u=${models_path}/graph/HCLG.fst
utt2spk_u=${scp_path}/utt2spk
cmvn_u=${scp_path}/cmvn.scp
feats_u=${scp_path}/feats.scp
output_path=$online_path/result

rm $scp_path/*

find $audio_path -iname "*.wav" > $scp_path/wav.flist

sed -e 's/\.wav//' $scp_path/wav.flist | awk -F '/' '{print $NF}' > $scp_path/utt.list

# 按/分隔取倒数第二个，也就是取wav所在目录的目录名做speaker
sed -e 's/\.wav//' $scp_path/wav.flist | awk -F '/' '{i=NF-1;printf("%s %s\n",$NF,$i)}' > $scp_path/utt2spk_all
# 以文件名为speaker
# sed -e 's/\.wav//' $scp_path/wav.flist | awk -F '/' '{printf("%s %s\n",$NF,$NF)}' > $scp_path/utt2spk_all

paste -d' ' $scp_path/utt.list $scp_path/wav.flist > $scp_path/wav.scp_all

utils/filter_scp.pl -f 1 $scp_path/utt.list $scp_path/utt2spk_all | sort -u > $scp_path/utt2spk
utils/filter_scp.pl -f 1 $scp_path/utt.list $scp_path/wav.scp_all | sort -u > $scp_path/wav.scp

utils/utt2spk_to_spk2utt.pl $scp_path/utt2spk > $scp_path/spk2utt

echo "scp utt2spk already!"

# sox a1.wav -b 16 aa1.wav
# sox aa1.wav -r 16000 a1.wav
rm -rf $output_path/*
${s5_path}/steps/make_mfcc_pitch.sh --cmd "run.pl" --nj 1 $scp_path $output_path/make_mfcc $output_path/mfcc || exit 1;

echo "extracted!"

${s5_path}/steps/compute_cmvn_stats.sh $scp_path $output_path/make_mfcc $output_path/mfcc || exit 1;
${s5_path}/utils/fix_data_dir.sh $scp_path || exit 1;

echo "prepared!"

# --acoustic-scale        : Scaling factor for acoustic likelihoods (float, default = 0.1)
# --beam               : Decoding beam.  Larger->slower, more accurate. (float, default = 16)
# --beam-delta            : Increment used in decoding-- this parameter is obscure and relates to a speedup in the way the max-active constraint is applied.  Larger is more accurate. (float, default = 0.5)
# --delta              : Tolerance used in determinization (float, default = 0.000976562)
# --determinize-lattice     : If true, determinize the lattice (lattice-determinization, keeping only best pdf-sequence for each word-sequence). (bool, default = true)
# --hash-ratio                : Setting used in decoder to control hash behavior (float, default = 2)
# --lattice-beam              : Lattice generation beam.  Larger->slower, and deeper lattices (float, default = 10)
# --max-active                : Decoder max active states.  Larger->slower; more accurate (int, default = 2147483647)
# --max-mem             : Maximum approximate memory usage in determinization (real usage might be many times this). (int, default = 50000000)
# --min-active                : Decoder minimum #active states. (int, default = 200)
# --minimize                  : If true, push and minimize after determinization. (bool, default = false)
# --phone-determinize    : If true, do an initial pass of determinization on both phones and words (see also --word-determinize) (bool, default = true)
# --prune-interval            : Interval (in frames) at which to prune tokens (int, default = 25)
# --word-determinize          : If true, do a second pass of determinization on words only (see also --phone-determinize) (bool, default = true)
# --word-symbol-table         : Symbol table for words [for debug output] (string, default = "")


# gmm-latgen-faster --max-active=7000 --beam=13.0 --lattice-beam=6.0 --acoustic-scale=0.083333 --word-symbol-table=${words_u} ${model_u} ${hclg_u} "ark,s,cs:apply-cmvn  --utt2spk=ark:${utt2spk_u} scp:${cmvn_u} scp:${feats_u} ark:- | splice-feats  ark:- ark:- | transform-feats ${models_path}/final.mat ark:- ark:- |" "ark:|gzip -c > ${output_path}/lat.1.gz"

gmm-latgen-faster --max-active=7000 --beam=13.0 --lattice-beam=11.0 --determinize-lattice=false --word-symbol-table=${words_u} ${model_u} ${hclg_u} "ark,s,cs:apply-cmvn  --utt2spk=ark:${utt2spk_u} scp:${cmvn_u} scp:${feats_u} ark:- | splice-feats  ark:- ark:- | transform-feats ${models_path}/final.mat ark:- ark:- |" "ark:-"

# gmm-latgen-faster --max-active=2000 --beam=8.0 --lattice-beam=6.0 --acoustic-scale=0.083333 --allow-partial=true --word-symbol-table=${words_u} ${models_path}/final.alimdl ${hclg_u} "ark,s,cs:apply-cmvn --utt2spk=ark:${utt2spk_u} scp:${cmvn_u} scp:${feats_u} ark:- | splice-feats ark:- ark:- | transform-feats ${models_path}/final.mat ark:- ark:- |" "ark:-"

exit 0;
