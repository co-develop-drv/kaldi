#!/bin/bash

# Copyright 2012-2016  Johns Hopkins University (Author: Daniel Povey)
# Apache 2.0
# To be run from .. (one directory up from here)
# see ../run.sh for example


# . ./path.sh
# . ./cmd.sh

#循环内部，以train为例
# Begin configuration section.
nj=4
cmd=run.pl
mfcc_config=conf/mfcc.conf
compress=true
write_utt2num_frames=false  # if true writes utt2num_frames
# End configuration section.

echo "$0 $@"  # Print the command line for logging : aaa.sh --nj 8 --cmd run.pl data/mfcc/train exp/make_mfcc/train mfcc/train
echo

if [ -f path.sh ]; then . ./path.sh; fi
. parse_options.sh || exit 1;  #需要用bash执行，有sh(dash)不支持的循环语法，将"--"前缀的参数值放到上面的变量里:nj、cmd
# echo "$0 $@"  #参数个数变成3了，aaa.sh data/mfcc/train exp/make_mfcc/train mfcc/train
if [ $# -lt 1 ] || [ $# -gt 3 ]; then
   echo "Usage: $0 [options] <data-dir> [<log-dir> [<mfcc-dir>] ]";
   echo "e.g.: $0 data/train exp/make_mfcc/train mfcc"
   echo "Note: <log-dir> defaults to <data-dir>/log, and <mfccdir> defaults to <data-dir>/data"
   echo "Options: "
   echo "  --mfcc-config <config-file>                      # config passed to compute-mfcc-feats "
   echo "  --nj <nj>                                        # number of parallel jobs"
   echo "  --cmd (utils/run.pl|utils/queue.pl <queue opts>) # how to run jobs."
   echo "  --write-utt2num-frames <true|false>     # If true, write utt2num_frames file."
   exit 1;
fi

data=$1
if [ $# -ge 2 ]; then
  logdir=$2
else
  logdir=$data/log
fi
if [ $# -ge 3 ]; then
  mfccdir=$3
else
  mfccdir=$data/data
fi

# make $mfccdir an absolute pathname.
mfccdir=`perl -e '($dir,$pwd)= @ARGV; if($dir!~m:^/:) { $dir = "$pwd/$dir"; } print $dir; ' $mfccdir ${PWD}`

# use "name" as part of name of the archive.
name=`basename $data` # train
# echo $data data/mfcc/train

mkdir -p $mfccdir || exit 1;
mkdir -p $logdir || exit 1;

#存在则建个隐藏目录备份
if [ -f $data/feats.scp ]; then
  mkdir -p $data/.backup
  echo "$0: moving $data/feats.scp to $data/.backup"
  mv $data/feats.scp $data/.backup
fi

scp=$data/wav.scp

required="$scp $mfcc_config"
# echo $required # data/mfcc/train/wav.scp conf/mfcc.conf
# 这两个文件有一个不存在报错退出
for f in $required; do
  if [ ! -f $f ]; then
    echo "make_mfcc.sh: no such file $f"
    exit 1;
  fi
done
utils/validate_data_dir.sh --no-text --no-feats $data || exit 1; #没什么特别值得说的，主要是通过临时文件检查准备的文件和之前生成的文件是否齐全，内容、互相的对应、排序等是否正确，包括很多可选文件如果存在的话，判断逻辑几乎都差不多，我感觉应该可以用函数简化一下

#VTLN:Vocal Tract Length Normalisation 声道长度归一化
if [ -f $data/spk2warp ]; then
  echo "$0 [info]: using VTLN warp factors from $data/spk2warp"
  vtln_opts="--vtln-map=ark:$data/spk2warp --utt2spk=ark:$data/utt2spk"
elif [ -f $data/utt2warp ]; then
  echo "$0 [info]: using VTLN warp factors from $data/utt2warp"
  vtln_opts="--vtln-map=ark:$data/utt2warp"
fi

for n in $(seq $nj); do
  # the next command does nothing unless $mfccdir/storage/ exists, see
  # utils/create_data_link.pl for more info.
#   echo "$mfccdir/raw_mfcc_$name.$n.ark"
  #以train为例kaldi-trunk/egs/thchs30/s5/mfcc/train/storage不存在则不执行
  utils/create_data_link.pl $mfccdir/raw_mfcc_$name.$n.ark
done


if $write_utt2num_frames; then
  write_num_frames_opt="--write-num-frames=ark,t:$logdir/utt2num_frames.JOB"
else
  write_num_frames_opt=
fi
# echo $write_utt2num_frames
# segment-begin 和 segment-end单位都是秒。指明了一段发音在一段录音中的时间偏移量
if [ -f $data/segments ]; then
  echo "$0 [info]: segments file exists: using that."

  split_segments=""
  for n in $(seq $nj); do
    split_segments="$split_segments $logdir/segments.$n"
  done

  utils/split_scp.pl $data/segments $split_segments || exit 1;
  rm $logdir/.error 2>/dev/null

  $cmd JOB=1:$nj $logdir/make_mfcc_${name}.JOB.log \
    extract-segments scp,p:$scp $logdir/segments.JOB ark:- \| \
    compute-mfcc-feats $vtln_opts --verbose=2 --config=$mfcc_config ark:- ark:- \| \
    copy-feats --compress=$compress $write_num_frames_opt ark:- \
      ark,scp:$mfccdir/raw_mfcc_$name.JOB.ark,$mfccdir/raw_mfcc_$name.JOB.scp \
     || exit 1;

else
  echo "$0: [info]: no segments file exists: assuming wav.scp indexed by utterance."
  split_scps=""
  for n in $(seq $nj); do
    split_scps="$split_scps $logdir/wav_${name}.$n.scp"
  done
  echo "$split_scps";  #exp/make_mfcc/train/wav_train.1.scp exp/make_mfcc/train/wav_train.2.scp exp/make_mfcc/train/wav_train.3.scp exp/make_mfcc/train/wav_train.4.scp exp/make_mfcc/train/wav_train.5.scp exp/make_mfcc/train/wav_train.6.scp exp/make_mfcc/train/wav_train.7.scp exp/make_mfcc/train/wav_train.8.scp

#   utils/split_scp.pl $scp $split_scps || exit 1;


#   # add ,p to the input rspecifier so that we can just skip over
#   # utterances that have bad wave data.

#   $cmd JOB=1:$nj $logdir/make_mfcc_${name}.JOB.log \
#     compute-mfcc-feats  $vtln_opts --verbose=2 --config=$mfcc_config \
#      scp,p:$logdir/wav_${name}.JOB.scp ark:- \| \
#       copy-feats $write_num_frames_opt --compress=$compress ark:- \
#       ark,scp:$mfccdir/raw_mfcc_$name.JOB.ark,$mfccdir/raw_mfcc_$name.JOB.scp \
#       || exit 1;
fi


# if [ -f $logdir/.error.$name ]; then
#   echo "Error producing mfcc features for $name:"
#   tail $logdir/make_mfcc_${name}.1.log
#   exit 1;
# fi

# # concatenate the .scp files together.
# for n in $(seq $nj); do
#   cat $mfccdir/raw_mfcc_$name.$n.scp || exit 1;
# done > $data/feats.scp || exit 1

# if $write_utt2num_frames; then
#   for n in $(seq $nj); do
#     cat $logdir/utt2num_frames.$n || exit 1;
#   done > $data/utt2num_frames || exit 1
#   rm $logdir/utt2num_frames.*
# fi

# rm $logdir/wav_${name}.*.scp  $logdir/segments.* 2>/dev/null

# nf=`cat $data/feats.scp | wc -l`
# nu=`cat $data/utt2spk | wc -l`
# if [ $nf -ne $nu ]; then
#   echo "It seems not all of the feature files were successfully processed ($nf != $nu);"
#   echo "consider using utils/fix_data_dir.sh $data"
# fi

# if [ $nf -lt $[$nu - ($nu/20)] ]; then
#   echo "Less than 95% the features were successfully generated.  Probably a serious error."
#   exit 1;
# fi

# echo "Succeeded creating MFCC features for $name"