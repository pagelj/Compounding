#!/usr/bin/env python

"""
Main python file for Compositionality Over Time

From here, run all experiments.
"""

import argparse
import cohaplusparser


def parse_args() -> argparse.ArgumentParser:
    """
    Parse all arguments needed for the main function and its subprocesses.
    """

    handler = argparse.ArgumentParser(description='Program to process the coha pickle files and store the 5-gram files akin to google N-grams V3')

    handler.add_argument('--input', type=str,
                        help='location of the directory with the coha sentence pickle files')

    handler.add_argument('--output', type=str,
                        help='directory to save dataset in')
    
    handler.add_argument('--reddy90', type=str,
                        help='Location of the 90 Reddy compounds')
    
    handler.add_argument('--cordeiro90', type=str,
                        help='Location of the subset of 90 Cordeiro compounds')
    
    handler.add_argument('--cordeiro100', type=str,
                        help='Location of the subset of 100 Cordeiro compounds')
    
    handler.add_argument('--unit', type=str, choices={"phrases", "words", "compounds"},
                         help='Unit that should be processed, either "phrases", "words" or "compounds"')


    args = handler.parse_args()
    
    return args


def main() -> None:
    args = parse_args()
    cohaplusparser.parse_coha_plus(args)

if __name__ == "__main__":
    main()
