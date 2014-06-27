Filename
===
swap.sh

Author
===
Felix Wong <fwong@palantir.com>

Description
===
Provides a way to swap the names of two files (useful for testing multiple config points by swapping config files)

Usage
===
`swap.sh file_1 file_2`

Key features
===
1. It can infer file_2 in the same directoy as file_1

        # Works as long as file2 is in the same folder as file1
        swap.sh ./folder1/file1 file2

2. It will not swap files in two separate folders

        # This will not work
        swap.sh ./folder1/file1 ./file2

3. It can resolve "different" folder paths

        # This can work
        swap.sh ~/folder1/file1 /home/hedgehog/folder1/file2
        # Or this assuming the CWD (current working directory) is ~/
        swap.sh ~/folder1/file1 ./folder1/file2
        # Or even this
        swap.sh ~/folder1/file1 folder1/file2

4. It can restore the original names by running the same command twice (great for automation scripts)

        # swaps the names
        swap.sh file1 file2
        # swaps the names back to their originals
        swap.sh file1 file2

* Based on the logic and implementation, the script can probably swap directories, but this hasn't been tested

Slick note
===
With a few modifications (like making all variables local), this can be put into the shell init script as a function; great for swapping via the terminal
