#!/bin/csh
#
# LSF batch script to run the test MPI code
#
#BSUB -P NMMM0024                       # Project 99999999
##BSUB -U wrfrtpm                        # use reservation
#BSUB -a poe                            # select poe
#BSUB -x                                # exclusive use of node (not_shared)
#BSUB -n 2048                           # number of total (MPI) tasks
#BSUB -R "span[ptile=16]"               # run a max of 8 tasks per node
#BSUB -J model15                        # job name
#BSUB -o model15%J.out                  # output filename
#BSUB -e model15%J.err                  # error filename
#BSUB -W 0:15                           # wallclock time
#BSUB -q economy                        # queue
##BSUB -w ended("init15")
#
#setenv LD_LIBRARY_PATH /glade/u/home/duda/libs_ifort13.1.2/netcdf/lib:$LD_LIBRARY_PATH
#ln -sf /glade/p/work/wrfrt/mpas/graph.info.part.4096 graph.info.part.4096
#
setenv LD_LIBRARY_PATH /glade/u/home/duda/libs_ifort13.1.2/netcdf/lib:$LD_LIBRARY_PATH
ln -sf /glade/p/work/wrfrt/mpas/x1.2621442.graph.info.part.2048 graph.info.part.2048
mpirun.lsf /glade/p/work/weiwang/MPAS14/merged/atmosphere_model.rh0
exit
