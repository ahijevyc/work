import pandas as pd
# Copied from tuna to cheyenne Jun 11, 2018

# Read SLOSH .trk file
# Manipulate it
# Write new SLOSH .trk file.

# ifile is the name of the .trk file to modify
ifile = "/Users/ahijevyc/Downloads/andrew.trk"

# ofile is the name of the new file.
ofile = "out.txt"

# Read list of lines so header and footer can be saved
lines = open(ifile).readlines()
header = ''.join(lines[0:2])
footer = ''.join(lines[-3:])


# Read other data into Pandas Dataframe
df = pd.read_fwf(ifile,skiprows=2, skipfooter=3, colspecs='infer',
   names=   ["NAP", "i_index", "latitude","longitude","speed","bearing", "dP", "RMW", "j_index", "NAP2"])


# Modify data
df.latitude = df.latitude - 1


# Format output into neat columns.
# In the format string between the curly brackets, spaces are important.
# na_rep='' replaces not-a-number (NaN) with empty string.
x = df.to_string(header=False,index=False,na_rep='',
   formatters={
      'NAP': '{:>15}'.format,
      'i_index': '{: 4d}'.format,
      'latitude': '{:7.4f}'.format,
      'longitude': '{: 7.3f}'.format,
      'speed': '{: 7.2f}'.format,
      'bearing': '{: 7.2f}'.format,
      'dP': '{: 7.2f}'.format,
      'RMW': '{: 7.2f}'.format,
      'j_index': '{: 4d}'.format,
   }
)


# Write output file
f = open(ofile, "w+")
f.write(header)
f.write('                   ')
f.write(x)
f.write('\n')
f.write(footer)
f.close()
