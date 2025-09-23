import pandas as pd
import csv
import os
import io
import zipfile
import tarfile
import spacy
import re
import time
import fasttext
import gc
import multiprocessing as mp
import argparse
import pickle

parser = argparse.ArgumentParser(description='Program to process the coha files and store the sentences for each decade')

parser.add_argument('--input', type=str,
                    help='location of the directory with the coha zip files')
parser.add_argument('--fasttext', type=str,
                    help='location of fasttext model')

parser.add_argument('--output', type=str,
                    help='directory to save dataset in')

parser.add_argument('--start_decade', type=str,
                    help='which decade to resume from')



args = parser.parse_args()



fmodel = fasttext.load_model(args.fasttext)


files_orig = []
tar_file = args.input
tar_obj = tarfile.open(tar_file)
file_names = tar_obj.getnames()
for member in tar_obj.getmembers():
    f = tar_obj.extractfile(member)
    content = f.read()
    files_orig.append(f)
    
decade_file_map = {}
for zfile, zfile_name in zip(files_orig, file_names):
    cur_decade=zfile_name.split('_')[2].rstrip('.zip')
    if cur_decade in decade_file_map:
        decade_file_map[cur_decade].append((zfile, zfile_name))
    else:
        decade_file_map[cur_decade] = [(zfile, zfile_name)]


def split_in_sentences(text,sent_segmenter):
    doc = sent_segmenter(text)
    return [str(sent).strip() for sent in doc.sents]

def lang_detect(sents):
    new_sents=[]
    for sent in sents:
        labels,conf=fmodel.predict(sent,k=-1)
        #if labels[0]=='__label__en' and conf[0]>0.8:
        if labels[0]=='__label__en':
            new_sents.append(sent)
    return new_sents


for cur_decade in decade_file_map:
    dec_time=time.time()
    print(cur_decade)
    if int(cur_decade.rstrip('s'))<int(args.start_decade.rstrip('s')):
        continue

    sent_dict={}
    zfiles_cur_decade = decade_file_map[cur_decade]
    for zfile_tuple in zfiles_cur_decade:
        zfile = zfile_tuple[0]
        zfile_name = zfile_tuple[1]
        print(zfile_name)

        df_list=[]
        zip_file_orig    = zipfile.ZipFile(zfile)
        zinfos_orig = zip_file_orig.infolist()

        names=[]
        sizes=[]
        ids=[]
        for i,zfile in enumerate(zinfos_orig):
            names.append(zfile.filename)
            ids.append(i)
            sizes.append(zfile.file_size)
        zfile_df=pd.DataFrame({'fid':ids,'fname':names,'fsize':sizes})
        zfile_df['fsize_perc']=zfile_df.fsize/zfile_df.fsize.sum()*100
        zfile_df.sort_values(by=['fsize'],ascending=False,inplace=True,ignore_index=True)
        zfile_df.fsize/=1024*1024

        file_list=zfile_df.fname.to_list()

        
        sent_segmenter=spacy.load('en_core_web_lg')
        sent_segmenter.disable_pipe("parser")
        sent_segmenter.disable_pipe("tok2vec")
        sent_segmenter.disable_pipe("tagger")
        sent_segmenter.disable_pipe("attribute_ruler")
        sent_segmenter.disable_pipe("lemmatizer")
        sent_segmenter.disable_pipe("ner")

        sent_segmenter.enable_pipe("senter")
        sent_segmenter.add_pipe("doc_cleaner")
        sent_segmenter.max_length=100_000_000

        n_proc = mp.cpu_count()-1
        for i,file_id in enumerate(file_list):
            print(f'File {i+1} out of {len(file_list)}')
            items_file_orig  = zip_file_orig.open(file_id, 'r')
            inp_text=io.TextIOWrapper(items_file_orig).read()
            cur_year=int(file_id.split('_')[2].rstrip('.txt'))
            inp_text=re.sub(r'^[^A-Za-z]*', '', inp_text)
            inp_text=re.sub(r'<.*?>', '', inp_text)
            inp_text=inp_text.replace("@ @ @ @ @ @ @ @ @ @","@@@@@@@@@@")
            inp_text = re.sub(r'\s+', ' ', inp_text).strip()
            #inp_text = inp_text.replace("1", "I").replace("0", "O")
            inp_text = re.sub(r'\.\s*\.\s*\.', '...', inp_text)
            inp_text = re.sub(r'\s+([.,!?])', r'\1', inp_text) 
            inp_text = re.sub(r'[^\x00-\x7F]+', '', inp_text)
            inp_text = re.sub(r'<.*?>', '', inp_text)
            #inp_text = inp_text.replace('5', 'S').replace('0', 'O').replace('1', 'I')
            #inp_text = re.sub(r'\bl\b', 'I', inp_text)
            inp_text = re.sub(r'(\w+)-\n(\w+)', r'\1\2', inp_text)  # Merge hyphenated line breaks
            inp_text = re.sub(r"[“”]", '"', inp_text)  # Normalize double quotes
            inp_text = re.sub(r"[‘’]", "'", inp_text) 
            inp_text = re.sub(r'(\w)[,.!?](\w)', r'\1 \2', inp_text)  # Add space after punctuation if missing
            inp_text = re.sub(r'[-=]{2,}', '', inp_text)  # Remove repetitive symbols
            #inp_text = re.sub(r'\b\d+\b', '', inp_text)  # Remove standalone numbers (if not meaningful)
            inp_text = re.sub(r'\n+', ' ', inp_text)  # Replace multiple line breaks with a single space
            print(f'Number of characters {len(inp_text)}')
            print(f"Running sentence segmenter")

            sents=split_in_sentences(inp_text,sent_segmenter)

            print(f'Number of sentences {len(sents)}')
            print(f"Running language identifier")


            sents=lang_detect(sents)
            print(f'Number of sentences {len(sents)}')
            sent_dict[file_id]=sents
            

    print(f"Total time taken for decade {cur_decade} : {round(time.time()-dec_time)} secs")
    with open(args.output+"/"+cur_decade+".pkl", 'wb') as f:
        pickle.dump(sent_dict, f)   
