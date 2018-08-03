        !COMPILER-GENERATED INTERFACE MODULE: Fri Aug  3 10:42:49 2018
        ! This source file is for reference only and may not completely
        ! represent the generated interface used by the compiler.
        MODULE SAVE_DATABASES__genmod
          INTERFACE 
            SUBROUTINE SAVE_DATABASES(PRNAME,NSPEC,NGLOB,IPROC_XI,      &
     &IPROC_ETA,NPROC_XI,NPROC_ETA,ADDRESSING,IMPICUT_XI,IMPICUT_ETA,   &
     &IBOOL,NODES_COORDS,ISPEC_MATERIAL_ID,NSPEC2D_XMIN,NSPEC2D_XMAX,   &
     &NSPEC2D_YMIN,NSPEC2D_YMAX,NSPEC2D_BOTTOM,NSPEC2D_TOP,             &
     &NSPEC2DMAX_XMIN_XMAX,NSPEC2DMAX_YMIN_YMAX,IBELM_XMIN,IBELM_XMAX,  &
     &IBELM_YMIN,IBELM_YMAX,IBELM_BOTTOM,IBELM_TOP,NMATERIALS,          &
     &MATERIAL_PROPERTIES,NSPEC_CPML,CPML_TO_SPEC,CPML_REGIONS,IS_CPML, &
     &XSTORE,YSTORE,ZSTORE)
              INTEGER(KIND=4), INTENT(IN) :: NSPEC_CPML
              INTEGER(KIND=4) :: NMATERIALS
              INTEGER(KIND=4) :: NSPEC2DMAX_YMIN_YMAX
              INTEGER(KIND=4) :: NSPEC2DMAX_XMIN_XMAX
              INTEGER(KIND=4) :: NSPEC2D_TOP
              INTEGER(KIND=4) :: NSPEC2D_BOTTOM
              INTEGER(KIND=4) :: NPROC_ETA
              INTEGER(KIND=4) :: NPROC_XI
              INTEGER(KIND=4) :: NGLOB
              INTEGER(KIND=4) :: NSPEC
              CHARACTER(LEN=512) :: PRNAME
              INTEGER(KIND=4) :: IPROC_XI
              INTEGER(KIND=4) :: IPROC_ETA
              INTEGER(KIND=4) :: ADDRESSING(0:NPROC_XI-1,0:NPROC_ETA-1)
              LOGICAL(KIND=4) :: IMPICUT_XI(2,NSPEC)
              LOGICAL(KIND=4) :: IMPICUT_ETA(2,NSPEC)
              INTEGER(KIND=4) :: IBOOL(2,2,2,NSPEC)
              REAL(KIND=8) :: NODES_COORDS(NGLOB,3)
              INTEGER(KIND=4) :: ISPEC_MATERIAL_ID(NSPEC)
              INTEGER(KIND=4) :: NSPEC2D_XMIN
              INTEGER(KIND=4) :: NSPEC2D_XMAX
              INTEGER(KIND=4) :: NSPEC2D_YMIN
              INTEGER(KIND=4) :: NSPEC2D_YMAX
              INTEGER(KIND=4) :: IBELM_XMIN(NSPEC2DMAX_XMIN_XMAX)
              INTEGER(KIND=4) :: IBELM_XMAX(NSPEC2DMAX_XMIN_XMAX)
              INTEGER(KIND=4) :: IBELM_YMIN(NSPEC2DMAX_YMIN_YMAX)
              INTEGER(KIND=4) :: IBELM_YMAX(NSPEC2DMAX_YMIN_YMAX)
              INTEGER(KIND=4) :: IBELM_BOTTOM(NSPEC2D_BOTTOM)
              INTEGER(KIND=4) :: IBELM_TOP(NSPEC2D_TOP)
              REAL(KIND=8) :: MATERIAL_PROPERTIES(NMATERIALS,7)
              INTEGER(KIND=4), INTENT(IN) :: CPML_TO_SPEC(NSPEC_CPML)
              INTEGER(KIND=4), INTENT(IN) :: CPML_REGIONS(NSPEC_CPML)
              LOGICAL(KIND=4), INTENT(IN) :: IS_CPML(NSPEC)
              REAL(KIND=8) :: XSTORE(2,2,2,NSPEC)
              REAL(KIND=8) :: YSTORE(2,2,2,NSPEC)
              REAL(KIND=8) :: ZSTORE(2,2,2,NSPEC)
            END SUBROUTINE SAVE_DATABASES
          END INTERFACE 
        END MODULE SAVE_DATABASES__genmod