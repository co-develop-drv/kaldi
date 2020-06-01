#!/bin/bash

# todo 测试一下十秒切一段的方式，识别效果如何

. ./cmd.sh
. ./path.sh

# step 1: generate fbank features
obj_dir=data/test
audio_path=data/wav

rm -rf $obj_dir/*

find $audio_path -iname "*.wav" > $obj_dir/wav.flist
sed -e 's/\.wav//' $obj_dir/wav.flist | awk -F '/' '{i=NF-1;printf("%s-%s\n",$i,$NF)}' > $obj_dir/utt.list
sed -e 's/\.wav//' $obj_dir/wav.flist | awk -F '/' '{i=NF-1;printf("%s-%s %s\n",$i,$NF,$i)}' > $obj_dir/utt2spk_all
paste -d' ' $obj_dir/utt.list $obj_dir/wav.flist > $obj_dir/wav.scp_all
utils/filter_scp.pl -f 1 $obj_dir/utt.list $obj_dir/utt2spk_all | sort -u > $obj_dir/utt2spk
utils/filter_scp.pl -f 1 $obj_dir/utt.list $obj_dir/wav.scp_all | sort -u > $obj_dir/wav.scp
utils/utt2spk_to_spk2utt.pl $obj_dir/utt2spk > $obj_dir/spk2utt

# 中间结果
mkdir -p work/data
# compute fbank without pitch
steps/make_fbank.sh --nj 1 --cmd "run.pl" $obj_dir exp/make_fbank/data work/data || exit 1;
# compute cmvn
steps/compute_cmvn_stats.sh $obj_dir exp/fbank_cmvn/data work/data || exit 1;#compute-cmvn-stats生成 cmvn_$name.scp 复制到 $1/cmvn.scp

# #step 2: offline-decoding
test_data=work/data
dir=exp/chain/tdnn

steps/nnet3/decode.sh --acwt 1.0 --post-decode-acwt 10.0 \
  --nj 1 --num-threads 1 \
  --cmd "$decode_cmd" --iter final \
  --frames-per-chunk 50 \
  $dir/graph $obj_dir # $dir/decode_test

. ./extract.sh

# # note: the model is trained using "apply-cmvn-online",
# # so you can modify the corresponding code in steps/nnet3/decode.sh to obtain the best performance,
# # but if you directly steps/nnet3/decode.sh, 
# # the performance is also good, but a little poor than the "apply-cmvn-online" method.
