#!/usr/bin/env python

"""
Functions to parse COHA+ data files and create Pandas DataFrame that contains all compounds and their context.
"""

import pandas as pd
import glob
import spacy
import pickle
import time
import multiprocessing as mp
from multiprocessing import Pool
import argparse


def get_reddy_cordeiro(args: argparse.ArgumentParser) -> pd.DataFrame:
    reddy90_path = args.reddy90
    cordeiro90_path = args.cordeiro90
    cordeiro100_path = args.cordeiro100
    reddy_df=pd.read_csv(reddy90_path,sep='\t')
    reddy_df['source']='reddy'
    cordeiro90_df=pd.read_csv(cordeiro90_path,sep='\t')
    cordeiro90_df['source']='cordeiro90'
    cordeiro100_df=pd.read_csv(cordeiro100_path,sep='\t')
    cordeiro100_df['source']='cordeiro100'
    comp_ratings_df=pd.concat([reddy_df,cordeiro90_df,cordeiro100_df])
    return comp_ratings_df


def compound_processor(sent_doc) -> pd.DataFrame:

    rows = []
    for chunk in sent_doc.noun_chunks:
        tokens = list(chunk)
        pos_tags = [token.pos_ for token in tokens]
        text_tokens = [token.text for token in tokens]
        lemmas = [token.lemma_ for token in tokens]
        deps = [token.dep_ if token.dep_ =="compound" else "noncomp" for token in chunk]
        ents = [token.ent_type_ if token.ent_type_ else "NOTNER" for token in tokens]

        chunk_start = chunk.start
        chunk_end = chunk.end

        if len(tokens) > 1:
            for i in range(len(tokens) - 1):
                pos_pair = [pos_tags[i], pos_tags[i+1]]
                if (pos_pair == ['ADJ', 'NOUN']) or (pos_pair == ['NOUN', 'NOUN']):
                        word_pair = [text_tokens[i], text_tokens[i+1]]
                        
                        lemma_pair = [lemmas[i], lemmas[i+1]]

                        compound_token = " ".join(f"{w}_{p}" for w, p in zip(word_pair, pos_pair))
                        compound_lemma = " ".join(f"{l}_{p}" for l, p in zip(lemma_pair, pos_pair))
                    
                        try:
                            compound_lemma_wo_pos=f'{lemmas[i]} {lemmas[i+1]}'
                        except IndexError as e:
                            print(compound_lemma_wo_pos)
                            print(compound_token)
                            print(compound_lemma)
                            print(f'{deps[i]} {deps[i+1]}')
                            print(f'{ents[i]} {ents[i+1]}')
                            
                        chunk_pos = " ".join(pos_pair)
                        compound_dep = f'{deps[i]} {deps[i+1]}'
                        compound_ner = f'{ents[i]} {ents[i+1]}'

                        prev_pos = pos_tags[i-1] if i-1 >= 0 else None
                        next_pos = pos_tags[i+2] if i+2 < len(pos_tags) else None

                        # phrase if previous or next word is also noun
                        if prev_pos == "NOUN" or next_pos == "NOUN":
                            chunk_type = "phrase"
                        else:
                            chunk_type = "compound"

                        # Context: all outside the chunk
                        context = [
                            f"{tok.lemma_}_{tok.pos_}"
                            for j, tok in enumerate(sent_doc)
                            if j < chunk_start or j >= chunk_end
                        ]

                        rows.append({
                            'compound_lemma_wo_pos': compound_lemma_wo_pos,
                            'compound_token': compound_token,
                            'compound_lemma': compound_lemma,
                            'chunk_pos': chunk_pos,
                            'compound_dep': compound_dep,
                            'compound_ner': compound_ner,
                            'context': context,
                            'chunk_type': chunk_type,
                        })
    if not rows:
        return None
    else:
        return pd.DataFrame(rows)


def word_processor(sent_doc) -> pd.DataFrame:
    rows = []
    for chunk in sent_doc.noun_chunks:
        tokens = list(chunk)
        pos_tags = [token.pos_ for token in tokens]
        text_tokens = [token.text for token in tokens]
        lemmas = [token.lemma_ for token in tokens]
        deps = [token.dep_ for token in tokens]
        ents = [token.ent_type_ if token.ent_type_ else "NOTNER" for token in tokens]

        chunk_start = chunk.start
        chunk_end = chunk.end

        for i, token in enumerate(tokens):
            if token.pos_ in ["ADJ", "NOUN"]:
                word_token = f"{token.text}_{token.pos_}"
                word_lemma = f"{token.lemma_}_{token.pos_}"

                # Context: all outside the chunk
                context = [
                    f"{tok.lemma_}_{tok.pos_}"
                    for j, tok in enumerate(sent_doc)
                    if j < chunk_start or j >= chunk_end
                ]

                rows.append({
                    "word_token": word_token,
                    "word_lemma": word_lemma,
                    "pos": token.pos_,
                    "ncompound": deps.count('compound'),
                    "ner": ents[i],
                    "context": context
                })

    if not rows:
        return None
    else:
        return pd.DataFrame(rows)
    

def sentence_processor(sent_doc) -> pd.DataFrame:
    rows = []
    for chunk in sent_doc.noun_chunks:
        tokens = list(chunk)
        pos_tags = [token.pos_ for token in tokens]
        text_tokens = [token.text for token in tokens]
        lemmas = [token.lemma_ for token in tokens]
        deps = [token.dep_ if token.dep_ =="compound" else "noncomp" for token in chunk]
        ents = [token.ent_type_ if token.ent_type_ else "NOTNER" for token in tokens]

        if len(tokens) > 1:
            for i in range(len(tokens) - 1):
                pos_pair = [pos_tags[i], pos_tags[i+1]]
                if (pos_pair == ['ADJ', 'NOUN']) or (pos_pair == ['NOUN', 'NOUN']):
                        word_pair = [text_tokens[i], text_tokens[i+1]]
                        
                        lemma_pair = [lemmas[i], lemmas[i+1]]

                        compound_token = " ".join(f"{w}_{p}" for w, p in zip(word_pair, pos_pair))
                        compound_lemma = " ".join(f"{l}_{p}" for l, p in zip(lemma_pair, pos_pair))
                    
                        try:
                            compound_lemma_wo_pos=f'{lemmas[i]} {lemmas[i+1]}'
                        except IndexError as e:
                            print(compound_lemma_wo_pos)
                            print(compound_token)
                            print(compound_lemma)
                            print(f'{deps[i]} {deps[i+1]}')
                            print(f'{ents[i]} {ents[i+1]}')
                            
                        chunk_pos = " ".join(pos_pair)
                        compound_dep = f'{deps[i]} {deps[i+1]}'
                        compound_ner = f'{ents[i]} {ents[i+1]}'

                        prev_pos = pos_tags[i-1] if i-1 >= 0 else None
                        next_pos = pos_tags[i+2] if i+2 < len(pos_tags) else None

                        # phrase if previous or next word is also noun
                        if prev_pos == "NOUN" or next_pos == "NOUN":
                            chunk_type = "phrase"
                        else:
                            chunk_type = "compound"

                        # context
                        chunk_start = chunk.start
                        chunk_end = chunk.end
                        context = [
                            f"{token.lemma_}_{token.pos_}" 
                            for j, token in enumerate(sent_doc) 
                            if j < chunk_start or j >= chunk_end
                        ]

                        rows.append({
                            'compound_lemma_wo_pos': compound_lemma_wo_pos,
                            'compound_token': compound_token,
                            'compound_lemma': compound_lemma,
                            'chunk_pos': chunk_pos,
                            'compound_dep': compound_dep,
                            'compound_ner': compound_ner,
                            'context': context,
                            'chunk_type': chunk_type
                        })
    if not rows:
        return None
    else:
        return pd.DataFrame(rows)


def parse_coha_plus(args: argparse.ArgumentParser) -> None:
    # Load the SpaCy model
    senter = spacy.load('en_core_web_lg')

    # Define decades that were already processed
    #already_processed = []
    already_processed = [1820, 1830, 1840, 1860, 1870, 1880, 1900, 1910, 1920, 1930, 1940, 1950, 1960, 1980, 1990, 2000]
    #already_processed = [1820, 1830, 1840, 1850, 1860, 1870, 1880, 1890, 1900, 1910, 1920, 1930, 1940, 1950, 1970, 1980, 1990, 2000, 2010]

    # List all pickle files

    _dir = args.input

    coha_files = glob.glob(_dir+'/*.pkl')
    print(f"Found {len(coha_files)} pickle files.")

    for pkl_path in coha_files:
        decade = pkl_path.split("/")[-1].replace(".pkl", "")
        if int(decade) in already_processed:
            continue
        print(f"\nProcessing decade: {decade}")

        with open(pkl_path, "rb") as f:
            coha_data = pickle.load(f)

        all_dfs = []

        for key, sentences in coha_data.items():
            domain = key.split("_")[1]
            print(f"  - Domain {domain}: {len(sentences)} sentences")

            # Process sentences in parallel
            docs = list(senter.pipe(sentences, n_process=mp.cpu_count()-2))

            with Pool(mp.cpu_count()-2) as pool:
                if args.unit == "phrases":
                    results = pool.map(sentence_processor, docs, chunksize=max(1, len(docs)//(mp.cpu_count()-2)))
                elif args.unit == "words":
                    results = pool.map(word_processor, docs, chunksize=max(1, len(docs)//(mp.cpu_count()-2)))
                elif args.unit == "compounds":
                    results = pool.map(compound_processor, docs, chunksize=max(1, len(docs)//(mp.cpu_count()-2)))

            results = [df for df in results if df is not None]
            
            if results:
                domain_df = pd.concat(results, ignore_index=True)
            
                comp_ratings_df = get_reddy_cordeiro(args)
                modifier_list=comp_ratings_df['modifier'].unique().tolist()
                head_list=comp_ratings_df['head'].unique().tolist()

                if args.unit == "phrases":
                    domain_df[['modifier','head']]=domain_df.compound_lemma_wo_pos.str.split(' ',expand=True)
                    domain_df=domain_df.loc[domain_df.modifier.isin(modifier_list)]
                    domain_df=domain_df.loc[domain_df['head'].isin(head_list)]
                domain_df=domain_df.explode(['context']).fillna("nan")
                domain_df=domain_df.loc[domain_df.context.str.contains(r"^.+_(?:PROPN|NOUN|ADJ|VERB|NUM|ADV)$")]
                domain_df['time'] = decade
                domain_df['domain'] = domain
                if args.unit == "phrases":
                    domain_df=domain_df.groupby(['compound_lemma','time','domain','chunk_pos','compound_dep','compound_ner','chunk_type','context']).size().to_frame()
                elif args.unit == "words":
                    domain_df=domain_df.groupby(['word_token','word_lemma','time','domain','pos','context']).size().to_frame()
                elif args.unit == "compounds":
                    domain_df=domain_df.groupby(['compound_token','compound_lemma','time','domain','chunk_pos','compound_dep','compound_ner','context','chunk_type']).size().to_frame()
                domain_df.columns=['count']
                domain_df=domain_df.reset_index()
                domain_df=domain_df.loc[domain_df.context.str.contains('@@@@@@@@@@')==False]

                all_dfs.append(domain_df)


        if all_dfs:
            final_decade_df = pd.concat(all_dfs, ignore_index=True)

            # Save
            output_path = f"{args.output}/cohaplus_{args.unit}_{decade}.csv"
            final_decade_df.to_csv(output_path, index=False)
            print(f"Saved: {output_path}")
        else:
            print(f"No valid compounds/phrases found for {decade}.")

    print("\n All done parsing COHA+ files!")
