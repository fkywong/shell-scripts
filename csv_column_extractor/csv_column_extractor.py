#!/usr/bin/env python

import argparse
import csv
import itertools


def __main():
    parser = argparse.ArgumentParser(description="Extract and print column(s) from a complex CSV file.",
                                     epilog="Note: printing multiple columns may be slow for large files " +\
                                            "because this program will process the file twice as a safeguard " +\
                                            "to prevent it from needing to read everything into memory at once.")
    parser.add_argument("csv_file", metavar="CSV_FILE",
                        help="path to the CSV file.")
    parser.add_argument("col_spec", metavar="COLUMN_SPEC", nargs="+",
                        help="Pythonic list indexing syntax (e.g. '0' denotes the first column, " +\
                            "'-1' denotes the last column, '0:2' denotes the first 2 columns, etc.). " +\
                            "Multiple indices and/or slices should be separated by a space, and output for " +\
                            "multiple columns will be printed in the order that the arguments were received " +\
                            "in a left-justified tabular format separated by \u2503.")
    args = parser.parse_args()
    cols = args.col_spec
    print_many_cols = len(cols) != 1 or not __str_parsable_as_int(cols[0])
    if print_many_cols:
        col_widths = dict()
        cols_to_get = [int(col) if __str_parsable_as_int(col)
                else slice(*map(lambda x: int(x.strip()) if x.strip() else None, col.split(':'))) for col in cols]
        with open(args.csv_file, "r") as csv_file:
            for row in csv.reader(csv_file):
                for i, v in enumerate(itertools.chain.from_iterable(row[col] if isinstance(row[col], list)
                        else itertools.repeat(row[col], 1) for col in cols_to_get)):
                    if col_widths.setdefault(i, len(v)) < len(v):
                        col_widths[i] = len(v)
            csv_file.seek(0)
            for row in csv.reader(csv_file):
                fmt = "  \u2503  ".join("{{:{}}}".format(col_widths[i]) for i in range(len(col_widths)))
                print(fmt.format(*list(itertools.chain.from_iterable(row[col] if isinstance(row[col], list)
                        else itertools.repeat(row[col], 1) for col in cols_to_get))))
    else:
        with open(args.csv_file, "r") as csv_file:
            for row in csv.reader(csv_file):
                print(row[int(cols[0])])


def __str_parsable_as_int(s):
    try:
        int(s)
        return True
    except ValueError:
        return False


if __name__ == "__main__":
    __main()
