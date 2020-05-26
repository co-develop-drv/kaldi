#!/usr/bin/env python

import sys

def extract():
#     print (sys.argv)
    cn_lines = []
    with open(sys.argv[1],'r') as txt:
        data = txt.read()
        index = 1
        for char in data:
            if (char == '\n'):
                index += 1
            elif (not char.islower() and not char.isupper()):
                if (index not in cn_lines):
                    cn_lines.append(index)
    return cn_lines


if __name__ == "__main__":
    result = extract()
    print(str(result).strip('[').strip(']'))

    # awk -v arr="${lines}" -v dict_dir="$dict_dir" 'BEGIN{split(arr,line_arr,","); i=1;}{if(NR==line_arr[i]){ if(i < length(line_arr)){i+=1;} print $0 >> dict_dir"/lexicon-en/words-en-oov-other.txt";} else{print $0 >> dict_dir"/lexicon-en/words-en-oov.txt";} }' $dict_dir/lexicon-en/words-en-oov-all.txt
