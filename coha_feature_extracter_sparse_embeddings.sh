lss#!/bin/sh


python src/coha_feature_extracter_sparse_embeddings.py --inputdir ../Compounding/datasets/ --reddy90 data/reddy_90.txt --cordeiro90 data/cordeiro_90.txt --cordeiro100 data/cordeiro_100.txt --outputdir ../Compounding/datasets/coha


python src/coha_feature_extracter_temporal_variation.py --inputdir ../Compounding/datasets/ --reddy90 data/reddy_90.txt --cordeiro90 data/cordeiro_90.txt --cordeiro100 data/cordeiro_100.txt --outputdir ../Compounding/datasets/coha


python src/coha_feature_extracter_sparse_embeddings.py --inputdir ../Compounding/datasets/ --reddy90 data/reddy_90.txt --cordeiro90 data/cordeiro_90.txt --cordeiro100 data/cordeiro_100.txt --outputdir ../Compounding/datasets/coha --ppmi


python src/coha_feature_extracter_temporal_variation.py --inputdir ../Compounding/datasets/ --reddy90 data/reddy_90.txt --cordeiro90 data/cordeiro_90.txt --cordeiro100 data/cordeiro_100.txt --outputdir ../Compounding/datasets/coha --ppmi


python src/coha_feature_extracter_sparse_embeddings.py --inputdir ../Compounding/datasets/ --reddy90 data/reddy_90.txt --cordeiro90 data/cordeiro_90.txt --cordeiro100 data/cordeiro_100.txt --outputdir ../Compounding/datasets/coha --tag

python src/coha_feature_extracter_temporal_variation.py --inputdir ../Compounding/datasets/ --reddy90 data/reddy_90.txt --cordeiro90 data/cordeiro_90.txt --cordeiro100 data/cordeiro_100.txt --outputdir ../Compounding/datasets/coha --tag


python src/coha_feature_extracter_sparse_embeddings.py --inputdir ../Compounding/datasets/ --reddy90 data/reddy_90.txt --cordeiro90 data/cordeiro_90.txt --cordeiro100 data/cordeiro_100.txt --outputdir ../Compounding/datasets/coha --ppmi --tag