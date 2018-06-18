#!/bin/csh

setenv TMPDIR /glade/scratch/$USER/temp
foreach iregion (0 1 2 3 4 5 6)
    foreach fcsth (24 48 72 96 120 144 168 192 216 240)
        set sbatch=$TMPDIR/$iregion.$fcsth.sbatch
cat <<END > $sbatch
#!/bin/csh
#SBATCH -A P64000101
#SBATCH -J $iregion.$fcsth
#SBATCH -t 01:00:00
#SBATCH --mem=50G # Each process uses 18G - reserve 50G to be safe
#SBATCH -p dav
#SBATCH -C geyser

### Initialize the Slurm environment
source /glade/u/apps/opt/slurm_init/init.csh

setenv TMPDIR /glade/scratch/$USER/temp
mkdir -p $TMPDIR
module purge
module load intel
#module load ncarenv ncarbinlibs peak_memusage
module load ncarenv ncarbinlibs 
module load ncl
module li

# Create image with NCL
setenv NCL_DEF_LIB_DIR /glade/u/home/ahijevyc/src/ncl_shared_objects/

#peak_memusage.exe ncl iregion=$iregion fcsth=$fcsth /glade2/work/ahijevyc/ncl/ACC.multi.ncl
ncl iregion=$iregion fcsth=$fcsth /glade2/work/ahijevyc/ncl/ACC.multi.ncl

END
        module load slurm
        sbatch $sbatch
        sleep 2
    end

end
