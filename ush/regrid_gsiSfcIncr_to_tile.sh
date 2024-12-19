#! /usr/bin/env bash

source "${USHgfs}/preamble.sh"

#-------------------------------------------------------------------------------------------------
# Script to regrid surface increment from GSI grid 
# to fv3 tiles. 
# Clara Draper, Dec 2024
#-------------------------------------------------------------------------------------------------

export PGMOUT=${PGMOUT:-${pgmout:-'&1'}}
export PGMERR=${PGMERR:-${pgmerr:-'&2'}}
export REDOUT=${REDOUT:-'1>'}
export REDERR=${REDERR:-'2>'}

REGRID_EXEC=${HOMEgfs}/sorc/gdas.cd/build/bin/regridStates.x

export PGM=$REGRID_EXEC
export pgm=$PGM

NMEM_REGRID=${NMEM_REGRID:-1}
CASE_IN=${CASE_IN:-$CASE_ENS}


# get resolutions
CRES_IN=$(echo $CASE_IN | cut -c2-)
LONB_CASE_IN=$((4*CRES_IN))
LATB_CASE_IN=$((2*CRES_IN))

CRES_OUT=$(echo $CASE_OUT | cut -c2-)
ntiles=6

APREFIX="${RUN/enkf}.t${cyc}z."
APREFIX_ENS="enkfgdas.t${cyc}z."

cat << EOF > regrid.nml
 &config
  n_vars=4,
  variable_list(1)="soilt1_inc     ",
  variable_list(2)="soilt2_inc     ",
  variable_list(3)="slc1_inc     ",
  variable_list(4)="slc2_inc     ",
  missing_value=0.,
 /
 &input
  gridtype="gau_inc",
  ires=${LONB_CASE_IN},
  jres=${LATB_CASE_IN},
  fname="enkfgdas.sfci.nc",
  dir="./",
  fname_coord="gaussian_scrip.nc",
  dir_coord="./"
/

 &output
  gridtype="fv3_rst",
  ires=${CRES_OUT},
  jres=${CRES_OUT},
  fname="sfci",
  dir="./",
  fname_mask="vegetation_type" 
  dir_mask="./"
  dir_coord="$FIXorog",
 /
EOF

# fixed input files
ln -sf /scratch2/BMC/gsienkf/Clara.Draper/regridding/inputs/gaussian.${LONB_CASE_IN}.${LATB_CASE_IN}.nc gaussian_scrip.nc

# fixed output files
for n in $(seq 1 $ntiles); do
    ln -sf ${FIXorog}/${CASE_OUT}/sfc/${CASE_OUT}.mx${OCNRES_OUT}.vegetation_type.tile${n}.nc  vegetation_type.tile${n}.nc
done

#nfhrs=$(echo $IAUFHRS_ENKF | sed 's/,/ /g')
for imem in $(seq 1 $NMEM_REGRID); do
    if [[ $NMEM_REGRID > 1 ]]; then
        cmem=$(printf %03i $imem)
        memchar="mem$cmem"
     
        MEMDIR=${memchar} YMD=${PDY} HH=${cyc} declare_from_tmpl \
            COM_ATMOS_ANALYSIS_MEM:COM_ATMOS_ANALYSIS_TMPL

        COM_SOIL_ANALYSIS_MEM=$COM_ATMOS_ANALYSIS_MEM
    fi
 
    for FHR in $soilinc_fhrs; do
      ln -fs ${COM_SOIL_ANALYSIS_MEM}/${APREFIX_ENS}sfci0${FHR}.nc \
                ${DATA}/enkfgdas.sfci.nc

      $APRUN_REGR $REGRID_EXEC $REDOUT$PGMOUT $REDERR$PGMERR

      for n in $(seq 1 $ntiles); do
          mv ${DATA}/sfci.tile${n}.nc  ${COM_ATMOS_ANALYSIS_MEM}/sfci0${FHR}.tile${n}.nc 
      done
    done
done

exit 0

