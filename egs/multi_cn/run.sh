#! /bin/bash

# root_dir=`pwd`/../../..
root_dir="/export1/kaldi"

base_path=${root_dir}/egs/multi_cn
online_path=${base_path}/online
s5_path=${base_path}/s5
models_path=${online_path}/multi_cn_chain_sp_online

echo ${base_path}

. ${s5_path}/cmd.sh || exit 1;
. ${s5_path}/path.sh || exit 1;
bash ${s5_path}/utils/parse_options.sh || exit 1;

conf=${models_path}/conf/online.conf
words_u=${models_path}/words.txt
model_u=${models_path}/final.mdl
output_path=$online_path/result

audio_path=${online_path}/online/online-data/audio
scp_path=${online_path}/online/online-data/require
utt2spk_u=${scp_path}/utt2spk
cmvn_u=${scp_path}/cmvn.scp
feats_u=${scp_path}/feats.scp
wav_scp=$scp_path/wav.scp

# spk2utt=${online_path}/tables/spk2utt
# wav_scp=${online_path}/tables/wav.scp
# cmvn_u=${online_path}/tables/cmvn.scp
# feats_u=${online_path}/tables/feats.scp


# steps/make_mfcc_pitch_online.sh --cmd "$train_cmd" --nj 10 data/$c/test exp/make_mfcc/$c/test $mfccdir/$c || exit 1;

# steps/compute_cmvn_stats.sh data/$c/test exp/make_mfcc/$c/test $mfccdir/$c || exit 1;



# steps/decode_fmllr.sh --nj $decode_nj --num-threads $decode_num_threads --cmd "$decode_cmd" \
#         ${cleaned_dir}/graph_tg data/${c}/test ${cleaned_dir}/decode_${c}_tg

# local/chain/run_cnn_tdnn.sh --test-sets "$test_sets"

find $audio_path -iname "*.wav" > $scp_path/wav.flist
sed -e 's/\.wav//' $scp_path/wav.flist | awk -F '/' '{print $NF}' > $scp_path/utt.list
sed -e 's/\.wav//' $scp_path/wav.flist | awk -F '/' '{i=NF-1;printf("%s %s\n",$NF,$i)}' > $scp_path/utt2spk_all
paste -d' ' $scp_path/utt.list $scp_path/wav.flist > $scp_path/wav.scp_all
utils/filter_scp.pl -f 1 $scp_path/utt.list $scp_path/utt2spk_all | sort -u > $scp_path/utt2spk
utils/filter_scp.pl -f 1 $scp_path/utt.list $scp_path/wav.scp_all | sort -u > $scp_path/wav.scp
utils/utt2spk_to_spk2utt.pl $scp_path/utt2spk > $scp_path/spk2utt
echo "scp utt2spk already!"

rm -rf $output_path/*
steps/make_mfcc.sh --nj 1 --cmd "run.pl" $scp_path $output_path/make_mfcc $output_path/mfcc || exit 1;
echo "extracted!"

${s5_path}/steps/compute_cmvn_stats.sh $scp_path $output_path/make_mfcc $output_path/mfcc || exit 1;
${s5_path}/utils/fix_data_dir.sh $scp_path || exit 1;
echo "prepared!"

online2-wav-nnet3-latgen-faster --config=$conf --do-\
endpointing=false --frames-per-chunk=20 --extra-left-context-initial=0 --online=true --frame-\
subsampling-factor=3 --max-active=7000 --beam=15.0 --lattice-beam=6.0 --online=false --acoustic-\
scale=0.1 --word-symbol-table=multi_cn_chain_sp_online/words.txt multi_cn_chain_sp_online/final.mdl \
multi_cn_chain_sp_online/HCLG.fst ark:$spk2utt scp:$wav_scp ark,t:result.txt


# cvte:

# online2-wav-nnet3-latgen-faster --do-endpointing=false --online=false --feature-type=fbank --fbank-config=../../egs/cvte/s5/conf/fbank.conf --max-active=7000 --beam=15.0 --lattice-beam=6.0 --acoustic-scale=1.0 --word-symbol-table=../../egs/cvte/s5/exp/chain/tdnn/graph/words.txt ../../egs/cvte/s5/exp/chain/tdnn/final.mdl ../../egs/cvte/s5/exp/chain/tdnn/graph/HCLG.fst 'ark:echo utter1 utter1|' 'scp:echo utter1 /tmp/test1.wav|' ark:/dev/null

# nnet3-latgen-faster --frame-subsampling-factor=3 --frames-per-chunk=50 --extra-left-context=0 --extra-right-context=0 --extra-left-context-initial=-1 --extra-right-context-final=-1 --minimize=false --max-active=7000 --min-active=200 --beam=15.0 --lattice-beam=8.0 --acoustic-scale=1.0 --allow-partial=true --word-symbol-table=${words_u} ${model_u} ${hclg_u} "ark,s,cs:apply-cmvn --norm-means=true --norm-vars=false --utt2spk=ark:$spk2utt scp:${cmvn_u} scp:${feats_u} ark:- |" "ark:|lattice-scale --acoustic-scale=10.0 ark:- ark:- |" "ark:/dev/null"
