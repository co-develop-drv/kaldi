#!/usr/bin/env bash
# saaavsaaa

dir=$1
data_dir="primewords_md_2018_set1/primewords_md_2018_set1/audio_files/"   #$2

cd $dir


dir=`pwd`
data_dir='audio_files'

IFS=$'\n\n' # loop by line, not space
for line in `cat test_set1_transcript.json | sed 's/},/\n/g'`; do
    wav=`echo $line | grep -Po 'file[" :]+\K[^"]+'`
    path=`find $data_dir/ -name $wav`
#     echo `basename $path .wav` $dir/$path >> wav.scp
    txt=`echo $line | grep -Po 'text[" :]+\K[^"]+'`
    echo $txt
    user_id=`echo $line | grep -Po 'user_id[" :]+\K[^"]+'`
    echo $user_id
    id=`echo $line | grep -Po '"id[" :]+\K[^"]+'`
    echo $id
done




echo "creating data/{train,dev,test}"
rm -rf data/{train,dev,test}
mkdir -p data/{train,dev,test}

#create wav.scp, utt2spk.scp, spk2utt.scp, text
(
for x in train dev test; do
  echo "cleaning data/$x"
  cd $dir/data/$x
  rm -rf wav.scp utt2spk spk2utt word.txt phone.txt text
  echo "preparing scps and text in data/$x"
  #updated new "for loop" figured out the compatibility issue with Mac     created by Xi Chen, in 03/06/2018
  for nn in `find  $corpus_dir/$x -name "*.wav" | sort -u | xargs -I {} basename {} .wav`; do
      spkid=`echo $nn | awk -F"_" '{print "" $1}'`
      spk_char=`echo $spkid | sed 's/\([A-Z]\).*/\1/'`
      spk_num=`echo $spkid | sed 's/[A-Z]\([0-9]\)/\1/'`
      spkid=$(printf '%s%.2d' "$spk_char" "$spk_num")
      utt_num=`echo $nn | awk -F"_" '{print $2}'`
      uttid=$(printf '%s%.2d_%.3d' "$spk_char" "$spk_num" "$utt_num")
      echo $uttid $corpus_dir/$x/$nn.wav >> wav.scp
      echo $uttid $spkid >> utt2spk
      echo $uttid `sed -n 1p $corpus_dir/data/$nn.wav.trn` >> word.txt
      echo $uttid `sed -n 3p $corpus_dir/data/$nn.wav.trn` >> phone.txt
  done 
  cp word.txt text
  sort wav.scp -o wav.scp
  sort utt2spk -o utt2spk
  sort text -o text
  sort phone.txt -o phone.txt
done
) || exit 1

utils/utt2spk_to_spk2utt.pl data/train/utt2spk > data/train/spk2utt
utils/utt2spk_to_spk2utt.pl data/dev/utt2spk > data/dev/spk2utt
utils/utt2spk_to_spk2utt.pl data/test/utt2spk > data/test/spk2utt

echo "creating test_phone for phone decoding"
(
  rm -rf data/test_phone && cp -R data/test data/test_phone  || exit 1
  cd data/test_phone && rm text &&  cp phone.txt text || exit 1
)

