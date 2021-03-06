!=====================================================================
!
!               S p e c f e m 3 D  V e r s i o n  2 . 0
!               ---------------------------------------
!
!          Main authors: Dimitri Komatitsch and Jeroen Tromp
!    Princeton University, USA and University of Pau / CNRS / INRIA
! (c) Princeton University / California Institute of Technology and University of Pau / CNRS / INRIA
!                            November 2010
!
! This program is free software; you can redistribute it and/or modify
! it under the terms of the GNU General Public License as published by
! the Free Software Foundation; either version 2 of the License, or
! (at your option) any later version.
!
! This program is distributed in the hope that it will be useful,
! but WITHOUT ANY WARRANTY; without even the implied warranty of
! MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
! GNU General Public License for more details.
!
! You should have received a copy of the GNU General Public License along
! with this program; if not, write to the Free Software Foundation, Inc.,
! 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
!
!=====================================================================

!----
!----  locate_source finds the correct position of the source
!----

  subroutine locate_source_cubed(ibool,NSOURCES,myrank,NSPEC_AB,NGLOB_AB,xstore,ystore,zstore, &
                 xigll,yigll,zigll,NPROC,NGNOD,min_tshift_src_original, &
                 tshift_src,yr,jda,ho,mi,theta_source,phi_source,lat_source,long_source, &
                 DT,hdur,Mxx,Myy,Mzz,Mxy,Mxz,Myz, &
                 islice_selected_source,ispec_selected_source, &
                 xi_source,eta_source,gamma_source,CUBED_SPHERE_PROJECTION, &
                 COUPLING_TYPE,PRINT_SOURCE_TIME_FUNCTION, &
                 nu_source,iglob_is_surface_external_mesh,ispec_is_surface_external_mesh, &
                 ispec_is_acoustic,ispec_is_elastic, &
                 num_free_surface_faces,free_surface_ispec,free_surface_ijk)

  use constants
  use specfem_par, only: USE_FORCE_POINT_SOURCE,user_source_time_function,&
             comp_dir_vect_source_E,comp_dir_vect_source_N,comp_dir_vect_source_Z_UP,&
             factor_force_source
  implicit none

!  include "constants.h"

  integer NPROC
  integer NGNOD
  integer NSPEC_AB,NGLOB_AB,NSOURCES

  logical PRINT_SOURCE_TIME_FUNCTION,CUBED_SPHERE_PROJECTION
  integer COUPLING_TYPE

  double precision DT

  integer, dimension(NGLLX,NGLLY,NGLLZ,NSPEC_AB) :: ibool

  integer myrank

  ! arrays containing coordinates of the points
  real(kind=CUSTOM_REAL), dimension(NGLOB_AB) :: xstore,ystore,zstore

  logical, dimension(NSPEC_AB) :: ispec_is_acoustic,ispec_is_elastic

  integer yr,jda,ho,mi

  double precision,intent(inout) :: min_tshift_src_original
  double precision,dimension(NSOURCES),intent(inout) :: tshift_src
  double precision sec

  integer iprocloop

  integer i,j,k,ispec,iglob,iglob_selected,inode,iface,isource
  integer imin,imax,jmin,jmax,kmin,kmax,igll,jgll,kgll
  integer iselected,jselected,iface_selected,iadjust,jadjust
  integer iproc(1)

!  double precision dcost,p20,r_ellip
  !double precision rspl(NR),espl(NR),espl2(NR)

  double precision, dimension(NSOURCES) :: theta_source,phi_source
  double precision, dimension(NSOURCES) :: lat_source,long_source
  double precision, dimension(NSOURCES) :: cubed_x_source,cubed_y_source
  double precision dist
  double precision xi,eta,gamma,dx,dy,dz,dxi,deta

  ! Gauss-Lobatto-Legendre points of integration
  double precision xigll(NGLLX)
  double precision yigll(NGLLY)
  double precision zigll(NGLLZ)

  ! topology of the control points of the surface element
  integer iax,iay,iaz
  integer iaddx(NGNOD),iaddy(NGNOD),iaddz(NGNOD)

  ! coordinates of the control points of the surface element
  double precision xelm(NGNOD),yelm(NGNOD),zelm(NGNOD)

  integer iter_loop

  integer ia
  double precision x,y,z
  double precision xix,xiy,xiz
  double precision etax,etay,etaz
  double precision gammax,gammay,gammaz
  double precision dgamma

  double precision final_distance_source(NSOURCES)

  double precision x_target_source,y_target_source,z_target_source
  double precision r_target_source

  double precision,dimension(1) :: altitude_source,distmin_ele
  double precision,dimension(NPROC) :: distmin_ele_all,elevation_all
  double precision,dimension(4) :: elevation_node,dist_node

  integer islice_selected_source(NSOURCES)

  ! timer MPI
  double precision, external :: wtime
  double precision time_start,tCPU

  integer ispec_selected_source(NSOURCES)

  integer ngather, ns, ne, ig, is, ng

!WENBO
  integer, dimension(NGATHER_SOURCES,0:NPROC-1) :: ispec_selected_source_all
  double precision, dimension(NGATHER_SOURCES,0:NPROC-1) :: xi_source_all,eta_source_all,gamma_source_all, &
     final_distance_source_all,x_found_source_all,y_found_source_all,z_found_source_all
  double precision, dimension(3,3,NGATHER_SOURCES,0:NPROC-1) :: nu_source_all
!   integer, dimension(NGATHER_SOURCES,0:223) :: ispec_selected_source_all
!   double precision, dimension(NGATHER_SOURCES,0:223) :: xi_source_all,eta_source_all,gamma_source_all, &
!      final_distance_source_all,x_found_source_all,y_found_source_all,z_found_source_all
!   double precision, dimension(3,3,NGATHER_SOURCES,0:223) :: nu_source_all


  double precision, dimension(:), allocatable :: tmp_local
  double precision, dimension(:,:),allocatable :: tmp_all_local

  double precision hdur(NSOURCES)
  integer iorientation
  double precision stazi,stdip,thetan,phin,n(3)
  double precision :: f0,t0_ricker

  double precision, dimension(NSOURCES) :: Mxx,Myy,Mzz,Mxy,Mxz,Myz
  double precision st,ct,sp,cp
  double precision Mrr,Mtt,Mpp,Mrt,Mrp,Mtp
  double precision tinyMoment 
  double precision, dimension(NSOURCES) :: xi_source,eta_source,gamma_source
  double precision, dimension(3,3,NSOURCES) :: nu_source

  double precision, dimension(NSOURCES) :: lat,long,depth
  double precision moment_tensor(6,NSOURCES)

!  character(len=256) OUTPUT_FILES

  double precision, dimension(NSOURCES) :: x_found_source,y_found_source,z_found_source
  double precision, dimension(NSOURCES) :: elevation
  double precision distmin

  integer, dimension(:), allocatable :: tmp_i_local
  integer, dimension(:,:),allocatable :: tmp_i_all_local

  ! for surface locating and normal computing with external mesh
!  integer :: pt0_ix,pt0_iy,pt0_iz,pt1_ix,pt1_iy,pt1_iz,pt2_ix,pt2_iy,pt2_iz
  integer :: num_free_surface_faces
  double precision r_surf,theta_surf,phi_surf
!  real(kind=CUSTOM_REAL), dimension(3) :: u_vector,v_vector,w_vector
  logical, dimension(NGLOB_AB) :: iglob_is_surface_external_mesh
  logical, dimension(NSPEC_AB) :: ispec_is_surface_external_mesh
  integer, dimension(num_free_surface_faces) :: free_surface_ispec
  integer, dimension(3,NGLLSQUARE,num_free_surface_faces) :: free_surface_ijk

  integer ix_initial_guess_source,iy_initial_guess_source,iz_initial_guess_source

  integer, dimension(NSOURCES) :: idomain
  integer, dimension(NGATHER_SOURCES,0:NPROC-1) :: idomain_all

  ! get the base pathname for output files
  if(DEBUG_COUPLING) print *,'get valuse started'
!  call get_value_string(OUTPUT_FILES, 'OUTPUT_FILES', OUTPUT_FILES_PATH(1:len_trim(OUTPUT_FILES_PATH)))

  ! read all the sources
  if (USE_FORCE_POINT_SOURCE) then      
         call get_force(tshift_src,hdur,lat,long,depth,NSOURCES,min_tshift_src_original,factor_force_source,&
                  comp_dir_vect_source_E,comp_dir_vect_source_N,comp_dir_vect_source_Z_UP, &
                  user_source_time_function)
  else 
         call get_cmt(yr,jda,ho,mi,sec,tshift_src,hdur,lat,long,depth,moment_tensor, &
                   DT,NSOURCES,min_tshift_src_original,user_source_time_function)
  end if


  if(DEBUG_COUPLING) print *,'get value ended'
  ! checks half-durations
  do isource = 1, NSOURCES
    ! null half-duration indicates a Heaviside
    ! replace with very short error function
    if(hdur(isource) < 5. * DT) hdur(isource) = 5. * DT
  enddo

  ! define topology of the control element
  call usual_hex_nodes(NGNOD,iaddx,iaddy,iaddz)

  ! get MPI starting time
  time_start = wtime()

  ! user output
  if( myrank == 0 ) then
    if(CUBED_SPHERE_PROJECTION) then
      write(IMAIN,*) 'CUBED_SPHERE_PROJECTION'
    endif
  endif
   

  ! loop on all the sources
  do isource = 1,NSOURCES
    lat_source(isource)   =lat(isource)
    long_source(isource)  =long(isource)
    theta_source(isource) = PI/2.0d0 - lat(isource)*PI/180.0d0
!  if(.not.ELLIPTICITY) then
!    theta_source(isource) = PI/2.0d0 - lat(isource)*PI/180.0d0
!  else
!    theta_source(isource) = PI/2.0d0 - atan(0.99329534d0*dtan(lat(isource)*PI/180.0d0))
!  endif
   phi_source(isource) = long(isource)*PI/180.0d0


   ! get the moment tensor
     Mrr = moment_tensor(1,isource)
     Mtt = moment_tensor(2,isource)
     Mpp = moment_tensor(3,isource)
     Mrt = moment_tensor(4,isource)
     Mrp = moment_tensor(5,isource)
     Mtp = moment_tensor(6,isource)
     ! convert from a spherical to a Cartesian representation of the moment
     ! tensor
       st=dsin(theta_source(isource))
       ct=dcos(theta_source(isource))
       sp=dsin(phi_source(isource))
       cp=dcos(phi_source(isource))

    ! get the moment tensor
      Mxx(isource)=st*st*cp*cp*Mrr+ct*ct*cp*cp*Mtt+sp*sp*Mpp &
          +2.0d0*st*ct*cp*cp*Mrt-2.0d0*st*sp*cp*Mrp-2.0d0*ct*sp*cp*Mtp
      Myy(isource)=st*st*sp*sp*Mrr+ct*ct*sp*sp*Mtt+cp*cp*Mpp &
          +2.0d0*st*ct*sp*sp*Mrt+2.0d0*st*sp*cp*Mrp+2.0d0*ct*sp*cp*Mtp
      Mzz(isource)=ct*ct*Mrr+st*st*Mtt-2.0d0*st*ct*Mrt
      Mxy(isource)=st*st*sp*cp*Mrr+ct*ct*sp*cp*Mtt-sp*cp*Mpp &
          +2.0d0*st*ct*sp*cp*Mrt+st*(cp*cp-sp*sp)*Mrp+ct*(cp*cp-sp*sp)*Mtp
      Mxz(isource)=st*ct*cp*Mrr-st*ct*cp*Mtt &
          +(ct*ct-st*st)*cp*Mrt-ct*sp*Mrp+st*sp*Mtp
      Myz(isource)=st*ct*sp*Mrr-st*ct*sp*Mtt &
          +(ct*ct-st*st)*sp*Mrt+ct*cp*Mrp-st*cp*Mtp

    ! get approximate topography elevation at source long/lat coordinates
    ! set distance to huge initial value
    distmin = HUGEVAL
    if(num_free_surface_faces > 0) then
      iglob_selected = 1
      ! loop only on points inside the element
      ! exclude edges to ensure this point is not shared with other elements
      imin = 2
      imax = NGLLX - 1

      jmin = 2
      jmax = NGLLY - 1

      iselected = 0
      jselected = 0
      iface_selected = 0
      do iface=1,num_free_surface_faces
        do j=jmin,jmax
          do i=imin,imax

            ispec = free_surface_ispec(iface)
            igll = free_surface_ijk(1,(j-1)*NGLLY+i,iface)
            jgll = free_surface_ijk(2,(j-1)*NGLLY+i,iface)
            kgll = free_surface_ijk(3,(j-1)*NGLLY+i,iface)
            iglob = ibool(igll,jgll,kgll,ispec)
            r_surf=dsqrt(dble(xstore(iglob)**2)+dble(ystore(iglob)**2)+dble(zstore(iglob)**2))
            theta_surf=acos(zstore(iglob)/r_surf)
!            sin(phi_surf)=ystore(iglob)/r_surf/dsin(theta_surf)
            phi_surf=acos(dble(xstore(iglob))/(dble(r_surf)*dsin(theta_surf))*(1-1.0e-6))
            if(ystore(iglob)<-1.e-14) then
               phi_surf=-phi_surf+2*PI
            end if
            ! keep this point if it is closer to the receiver
!            if(ELLIPTICITY) then
!                dcost = dcos(theta_surf)
!                p20 = 0.5d0*(3.0d0*dcost*dcost-1.0d0)
!                call spline_evaluation(rspl,espl,espl2,nspl,R_EARTH,ell)
!                r_ellip = R_EARTH*(1.0d0-(2.0d0/3.0d0)*ell*p20)
!            end if
!             dist=dsqrt(2-2*dsin(theta_source(isource))*dsin(theta_surf)* &
!                  (dcos(phi_source(isource))*dcos(phi_surf)+sin(phi_source(isource))*sin(phi_surf)))
            dist= acos(cos(theta_source(isource))*cos(theta_surf) + &
                       sin(theta_source(isource))*sin(theta_surf)*cos(phi_source(isource)-phi_surf))*180.0d0/PI


            if(dist < distmin) then
              distmin = dist
              iglob_selected = iglob
              iface_selected = iface
              iselected = i
              jselected = j
              r_surf=dsqrt(dble(xstore(iglob_selected)**2)+ &
                     dble(ystore(iglob_selected)**2)+dble(zstore(iglob_selected)**2))
!              if(ELLIPTICITY) then
!                altitude_source(1) = r_surf-r_ellip
!              else
!                altitude_source(1) = r_surf-R_EARTH
!              end if
              altitude_source(1) = r_surf-R_EARTH_SURF
            endif
          enddo
        enddo
        ! end of loop on all the elements on the free surface
      end do
      !  weighted mean at current point of topography elevation of the four closest nodes
      !  set distance to huge initial value
      distmin = HUGEVAL
      do j=jselected,jselected+1
        do i=iselected,iselected+1
          inode = 1
          do jadjust=0,1
            do iadjust= 0,1
              ispec = free_surface_ispec(iface_selected)
              igll = free_surface_ijk(1,(j-jadjust-1)*NGLLY+i-iadjust,iface_selected)
              jgll = free_surface_ijk(2,(j-jadjust-1)*NGLLY+i-iadjust,iface_selected)
              kgll = free_surface_ijk(3,(j-jadjust-1)*NGLLY+i-iadjust,iface_selected)
              iglob = ibool(igll,jgll,kgll,ispec)
              r_surf=dsqrt(dble(xstore(iglob)**2)+dble(ystore(iglob)**2)+dble(zstore(iglob)**2))
              theta_surf=acos(zstore(iglob)/r_surf)
!            sin(phi_surf)=ystore(iglob)/r_surf/dsin(theta_surf)
              phi_surf=acos(dble(xstore(iglob))/(dble(r_surf)*dsin(theta_surf))*(1.d0-1.0e-6))
              if(ystore(iglob)<-1.e-14) then
                    phi_surf=-phi_surf+2*PI
              end if
!            if(ELLIPTICITY) then
!                dcost = dcos(theta_surf)
!                p20 = 0.5d0*(3.0d0*dcost*dcost-1.0d0)
!                call  spline_evaluation(rspl,espl,espl2,nspl,R_EARTH,ell)
!                r_ellip = R_EARTH*(1.0d0-(2.0d0/3.0d0)*ell*p20)
!                elevation_node(inode) = r_surf-r_ellip
!              else
!                elevation_node(inode) = r_surf-R_EARTH
!              end if

              elevation_node(inode) = r_surf-R_EARTH_SURF
!              dist_node(inode)=dsqrt(2-2*dsin(theta_source(isource))*dsin(theta_surf)* &
!                   (dcos(phi_source(isource))*dcos(phi_surf)+sin(phi_source(isource))*sin(phi_surf)))
               dist_node(inode)= acos(cos(theta_source(isource))*cos(theta_surf) + &
                       sin(theta_source(isource))*sin(theta_surf)*cos(phi_source(isource)-phi_surf))*180.0d0/PI

              inode = inode + 1
            end do
          end do
          dist = sum(dist_node)
          if(dist < distmin) then
            distmin = dist
            altitude_source(1) = (dist_node(1)/dist)*elevation_node(1) + &
                     (dist_node(2)/dist)*elevation_node(2) + &
                     (dist_node(3)/dist)*elevation_node(3) + &
                     (dist_node(4)/dist)*elevation_node(4)
          endif
        end do
      end do
    end if
    !  MPI communications to determine the best slice
    distmin_ele(1)= distmin
    call gather_all_dp(distmin_ele,1,distmin_ele_all,1,NPROC)
    call gather_all_dp(altitude_source,1,elevation_all,1,NPROC)
    if(myrank == 0) then
      iproc = minloc(distmin_ele_all)
      altitude_source(1) = elevation_all(iproc(1))
    end if
    call bcast_all_dp(altitude_source,1)
    elevation(isource) = altitude_source(1)

    ! orientation consistent with the cubed_sphere projection
    !     East
    nu_source(1,1,isource) = 1.d0
    nu_source(1,2,isource) = 0.d0
    nu_source(1,3,isource) = 0.d0
    !     North
    nu_source(2,1,isource) = 0.d0
    nu_source(2,2,isource) = 1.d0
    nu_source(2,3,isource) = 0.d0
    !     Vertical
    nu_source(3,1,isource) = 0.d0
    nu_source(3,2,isource) = 0.d0
    nu_source(3,3,isource) = 1.d0
    ! record three components for each station
    do iorientation = 1,3

      !   North
       if(iorientation == 1) then
          stazi = 0.d0
          stdip = 0.d0
      !    East
       else if(iorientation == 2) then
          stazi = 90.d0
          stdip = 0.d0
      !   Vertical
       else if(iorientation == 3) then
          stazi = 0.d0
          stdip = - 90.d0
       else
          call exit_MPI(myrank,'incorrect orientation')
       endif

      !   get the orientation of the seismometer
      thetan=(90.0d0+stdip)*PI/180.0d0
      phin=stazi*PI/180.0d0
      ! we use the same convention as in Harvard normal modes for the orientation
      !   vertical component
      n(1) = dcos(thetan)
      !   N-S component
      n(2) = - dsin(thetan)*dcos(phin)
      !   E-W component
      n(3) = dsin(thetan)*dsin(phin)
      !   get the Cartesian components of n in the model: nu
      nu_source(iorientation,1,isource) = n(1)*st*cp+n(2)*ct*cp-n(3)*sp
      nu_source(iorientation,2,isource) = n(1)*st*sp+n(2)*ct*sp+n(3)*cp
      nu_source(iorientation,3,isource) = n(1)*ct-n(2)*st
    enddo




!    if(ELLIPTICITY) then
!      dcost = dcos(theta_source(isource))
!      p20 = 0.5d0*(3.0d0*dcost*dcost-1.0d0)
!      call spline_evaluation(rspl,espl,espl2,nspl,R_EARTH,ell)
!      r_ellip_source  =  R_EARTH*(1.0d0-(2.0d0/3.0d0)*ell*p20) 
!      r_target_source =  r_ellip_source + elevation(isource) - depth(isource)*1000.0
!    else
!      r_target_source =  R_EARTH + elevation(isource) - depth(isource)*1000.0
!    endif
      r_target_source = R_EARTH_SURF + elevation(isource) - depth(isource)*1000.0
      x_target_source = r_target_source*dsin(theta_source(isource))*dcos(phi_source(isource))
      y_target_source = r_target_source*dsin(theta_source(isource))*dsin(phi_source(isource))
      z_target_source = r_target_source*dcos(theta_source(isource))

    ! set distance to huge initial value
    distmin = HUGEVAL

    ispec_selected_source(isource) = 0
    ix_initial_guess_source = 0
    iy_initial_guess_source = 0
    iz_initial_guess_source = 0
    do ispec=1,NSPEC_AB

      ! define the interval in which we look for points
      if(USE_FORCE_POINT_SOURCE) then
        imin = 1
        imax = NGLLX

        jmin = 1
        jmax = NGLLY

        kmin = 1
        kmax = NGLLZ

      else
        ! loop only on points inside the element
        ! exclude edges to ensure this point is not shared with other elements
        imin = 2
        imax = NGLLX - 1

        jmin = 2
        jmax = NGLLY - 1

        kmin = 2
        kmax = NGLLZ - 1
      endif

      do k = kmin,kmax
        do j = jmin,jmax
          do i = imin,imax

            iglob = ibool(i,j,k,ispec)

            if (.not. SOURCES_CAN_BE_BURIED) then
              if ((.not. iglob_is_surface_external_mesh(iglob)) .or. (.not. ispec_is_surface_external_mesh(ispec))) then
                cycle
              endif
            endif

            ! keep this point if it is closer to the source
            dist = dsqrt((x_target_source-dble(xstore(iglob)))**2 &
                  +(y_target_source-dble(ystore(iglob)))**2 &
                  +(z_target_source-dble(zstore(iglob)))**2)
            if(dist < distmin) then
              distmin = dist
              ispec_selected_source(isource) = ispec
              ix_initial_guess_source = i
              iy_initial_guess_source = j
              iz_initial_guess_source = k

              ! store xi,eta,gamma and x,y,z of point found
              ! note: they have range [1.0d0,NGLLX/Y/Z], used for point sources
              !          see e.g. in compute_add_source_elastic.f90
              xi_source(isource) = dble(ix_initial_guess_source)
              eta_source(isource) = dble(iy_initial_guess_source)
              gamma_source(isource) = dble(iz_initial_guess_source)

              x_found_source(isource) = xstore(iglob)
              y_found_source(isource) = ystore(iglob)
              z_found_source(isource) = zstore(iglob)

              ! compute final distance between asked and found (converted to km)
              final_distance_source(isource) = dsqrt((x_target_source-x_found_source(isource))**2 + &
                (y_target_source-y_found_source(isource))**2 + (z_target_source-z_found_source(isource))**2)

            endif

          enddo
        enddo
      enddo

    ! end of loop on all the elements in current slice
    enddo

    if (ispec_selected_source(isource) == 0) then
      final_distance_source(isource) = HUGEVAL
    endif

    ! sets whether acoustic (1) or elastic (2)
    if( ispec_is_acoustic( ispec_selected_source(isource) ) ) then
      if(DEBUG_COUPLING) print *,'ispec_selected_source(isource)=',ispec_selected_source(isource), &
          ispec_is_acoustic( ispec_selected_source(isource) )
      idomain(isource) = IDOMAIN_ACOUSTIC
    else if( ispec_is_elastic( ispec_selected_source(isource) ) ) then
      idomain(isource) = IDOMAIN_ELASTIC
    else
      idomain(isource) = 0
    endif


! *******************************************
! find the best (xi,eta,gamma) for the source
! *******************************************

    ! for point sources, the location will be exactly at a GLL point
    ! otherwise this tries to find best location
    if(.not. USE_FORCE_POINT_SOURCE) then

      ! uses actual location interpolators, in range [-1,1]
      xi = xigll(ix_initial_guess_source)
      eta = yigll(iy_initial_guess_source)
      gamma = zigll(iz_initial_guess_source)

      ! define coordinates of the control points of the element
      do ia=1,NGNOD
        iax = 0
        iay = 0
        iaz = 0
        if(iaddx(ia) == 0) then
          iax = 1
        else if(iaddx(ia) == 1) then
          iax = (NGLLX+1)/2
        else if(iaddx(ia) == 2) then
          iax = NGLLX
        else
          call exit_MPI(myrank,'incorrect value of iaddx')
        endif

        if(iaddy(ia) == 0) then
          iay = 1
        else if(iaddy(ia) == 1) then
          iay = (NGLLY+1)/2
        else if(iaddy(ia) == 2) then
          iay = NGLLY
        else
          call exit_MPI(myrank,'incorrect value of iaddy')
        endif

        if(iaddz(ia) == 0) then
          iaz = 1
        else if(iaddz(ia) == 1) then
          iaz = (NGLLZ+1)/2
        else if(iaddz(ia) == 2) then
          iaz = NGLLZ
        else
          call exit_MPI(myrank,'incorrect value of iaddz')
        endif

        iglob = ibool(iax,iay,iaz,ispec_selected_source(isource))
        xelm(ia) = dble(xstore(iglob))
        yelm(ia) = dble(ystore(iglob))
        zelm(ia) = dble(zstore(iglob))

      enddo

      ! iterate to solve the non linear system
      do iter_loop = 1,NUM_ITER

        ! recompute jacobian for the new point
        call recompute_jacobian(xelm,yelm,zelm,xi,eta,gamma,x,y,z, &
           xix,xiy,xiz,etax,etay,etaz,gammax,gammay,gammaz,NGNOD)

        ! compute distance to target location
        dx = - (x - x_target_source)
        dy = - (y - y_target_source)
        dz = - (z - z_target_source)

        ! compute increments
        dxi  = xix*dx + xiy*dy + xiz*dz
        deta = etax*dx + etay*dy + etaz*dz
        dgamma = gammax*dx + gammay*dy + gammaz*dz

        ! update values
        xi = xi + dxi
        eta = eta + deta
        gamma = gamma + dgamma

        ! impose that we stay in that element
        ! (useful if user gives a source outside the mesh for instance)
        if (xi > 1.d0) xi = 1.d0
        if (xi < -1.d0) xi = -1.d0
        if (eta > 1.d0) eta = 1.d0
        if (eta < -1.d0) eta = -1.d0
        if (gamma > 1.d0) gamma = 1.d0
        if (gamma < -1.d0) gamma = -1.d0

      enddo

      ! compute final coordinates of point found
      call recompute_jacobian(xelm,yelm,zelm,xi,eta,gamma,x,y,z, &
         xix,xiy,xiz,etax,etay,etaz,gammax,gammay,gammaz,NGNOD)

      ! store xi,eta,gamma and x,y,z of point found
      ! note: xi/eta/gamma will be in range [-1,1]
      xi_source(isource) = xi
      eta_source(isource) = eta
      gamma_source(isource) = gamma
      x_found_source(isource) = x
      y_found_source(isource) = y
      z_found_source(isource) = z

      ! compute final distance between asked and found (converted to km)
      final_distance_source(isource) = dsqrt((x_target_source-x_found_source(isource))**2 + &
        (y_target_source-y_found_source(isource))**2 + (z_target_source-z_found_source(isource))**2)

    endif ! of if (.not. USE_FORCE_POINT_SOURCE)

  ! end of loop on all the sources
  enddo

  ! now gather information from all the nodes
  ngather = NSOURCES/NGATHER_SOURCES
  if (mod(NSOURCES,NGATHER_SOURCES)/= 0) ngather = ngather+1
  do ig = 1, ngather
    ns = (ig-1) * NGATHER_SOURCES + 1
    ne = min(ig*NGATHER_SOURCES, NSOURCES)
    ng = ne - ns + 1

    ispec_selected_source_all(:,:) = -1

    ! avoids warnings about temporary creations of arrays for function call by compiler
    allocate(tmp_i_local(ng),tmp_i_all_local(ng,0:NPROC-1))
    tmp_i_local(:) = ispec_selected_source(ns:ne)
    call gather_all_i(tmp_i_local,ng,tmp_i_all_local,ng,NPROC)
    ispec_selected_source_all(1:ng,:) = tmp_i_all_local(:,:)

    ! acoustic/elastic domain
    tmp_i_local(:) = idomain(ns:ne)
    call gather_all_i(tmp_i_local,ng,tmp_i_all_local,ng,NPROC)
    idomain_all(1:ng,:) = tmp_i_all_local(:,:)

    deallocate(tmp_i_local,tmp_i_all_local)

    ! avoids warnings about temporary creations of arrays for function call by compiler
    allocate(tmp_local(ng),tmp_all_local(ng,0:NPROC-1))
    tmp_local(:) = xi_source(ns:ne)
    call gather_all_dp(tmp_local,ng,tmp_all_local,ng,NPROC)
    xi_source_all(1:ng,:) = tmp_all_local(:,:)

    tmp_local(:) = eta_source(ns:ne)
    call gather_all_dp(tmp_local,ng,tmp_all_local,ng,NPROC)
    eta_source_all(1:ng,:) = tmp_all_local(:,:)

    tmp_local(:) = gamma_source(ns:ne)
    call gather_all_dp(tmp_local,ng,tmp_all_local,ng,NPROC)
    gamma_source_all(1:ng,:) = tmp_all_local(:,:)

    tmp_local(:) = final_distance_source(ns:ne)
    call gather_all_dp(tmp_local,ng,tmp_all_local,ng,NPROC)
    final_distance_source_all(1:ng,:) = tmp_all_local(:,:)

    tmp_local(:) = x_found_source(ns:ne)
    call gather_all_dp(tmp_local,ng,tmp_all_local,ng,NPROC)
    x_found_source_all(1:ng,:) = tmp_all_local(:,:)

    tmp_local(:) = y_found_source(ns:ne)
    call gather_all_dp(tmp_local,ng,tmp_all_local,ng,NPROC)
    y_found_source_all(1:ng,:) = tmp_all_local(:,:)

    tmp_local(:) = z_found_source(ns:ne)
    call gather_all_dp(tmp_local,ng,tmp_all_local,ng,NPROC)
    z_found_source_all(1:ng,:) = tmp_all_local(:,:)

    do i=1,3
      do j=1,3
        tmp_local(:) = nu_source(i,j,ns:ne)
        call gather_all_dp(tmp_local,ng,tmp_all_local,ng,NPROC)
        nu_source_all(i,j,1:ng,:) = tmp_all_local(:,:)
      enddo
    enddo
    deallocate(tmp_local,tmp_all_local)

    ! this is executed by main process only
    if(myrank == 0) then

      ! check that the gather operation went well
      if(any(ispec_selected_source_all(1:ng,:) == -1)) call exit_MPI(myrank,'gather operation failed for source')

      ! loop on all the sources
      do is = 1,ng
        isource = ns + is - 1

        ! loop on all the results to determine the best slice
        distmin = HUGEVAL
        do iprocloop = 0,NPROC-1
          if(final_distance_source_all(is,iprocloop) < distmin) then
            distmin = final_distance_source_all(is,iprocloop)
            islice_selected_source(isource) = iprocloop
            ispec_selected_source(isource) = ispec_selected_source_all(is,iprocloop)
            xi_source(isource) = xi_source_all(is,iprocloop)
            eta_source(isource) = eta_source_all(is,iprocloop)
            gamma_source(isource) = gamma_source_all(is,iprocloop)
            x_found_source(isource) = x_found_source_all(is,iprocloop)
            y_found_source(isource) = y_found_source_all(is,iprocloop)
            z_found_source(isource) = z_found_source_all(is,iprocloop)
            nu_source(:,:,isource) = nu_source_all(:,:,isource,iprocloop)
            idomain(isource) = idomain_all(is,iprocloop)
          endif
        enddo
        final_distance_source(isource) = distmin

      enddo
    endif !myrank
  enddo ! ngather

  if (myrank == 0) then
   if(COUPLING_TYPE.eq.2.or.COUPLING_TYPE.eq.3) then
    if(NSOURCES.gt.1) call exit_MPI(myrank,'Only one source is permitted (NSOURCES=1) for COUPLING_TYPE=2 or 3')
    do isource=1,NSOURCES
      write(IMAIN,*) 'original (requested) position of the source:'
      write(IMAIN,*)
      write(IMAIN,*) '          latitude: ',lat(isource)
      write(IMAIN,*) '         longitude: ',long(isource)
      write(IMAIN,*)
      write(IMAIN,*) '            cubed_sphere theta: ',theta_source(isource)
      write(IMAIN,*) '            cubed_sphere phi: ',phi_source(isource)
      write(IMAIN,*) '         depth: ',depth(isource),' km'
      write(IMAIN,*) 'topo elevation: ',elevation(isource)
      write(IMAIN,*) 'Minimum distance to the source:',sngl(final_distance_source(isource)),' m'
      if(final_distance_source(isource)/1000.0.lt.500) then
          write(IMAIN,*) 'WARNING, the minimum distance is less than 500km, maybe not teleseismic distance!'
      end if
    end do


   else if(COUPLING_TYPE.eq.1.or.COUPLING_TYPE.eq.4) then

    do isource = 1,NSOURCES

      if(SHOW_DETAILS_LOCATE_SOURCE .or. NSOURCES == 1) then

        write(IMAIN,*)
        write(IMAIN,*) '*************************************'
        write(IMAIN,*) ' locating source ',isource
        write(IMAIN,*) '*************************************'
        write(IMAIN,*)
        write(IMAIN,*) 'source located in slice ',islice_selected_source(isource)
        write(IMAIN,*) '               in element ',ispec_selected_source(isource)

        if( idomain(isource) == IDOMAIN_ACOUSTIC ) then
          write(IMAIN,*) '               in acoustic domain'
        else if( idomain(isource) == IDOMAIN_ELASTIC ) then
          write(IMAIN,*) '               in elastic domain'
        else
          write(IMAIN,*) '               in unknown domain'
        endif

        write(IMAIN,*)
        if(USE_FORCE_POINT_SOURCE) then
          write(IMAIN,*) '  i index of source in that element: ',nint(xi_source(isource))
          write(IMAIN,*) '  j index of source in that element: ',nint(eta_source(isource))
          write(IMAIN,*) '  k index of source in that element: ',nint(gamma_source(isource))
          write(IMAIN,*)
          write(IMAIN,*) '  component of direction vector in East direction:',comp_dir_vect_source_E(isource)
          write(IMAIN,*) '  component of direction vector in North direction:',comp_dir_vect_source_N(isource)
          write(IMAIN,*) '  component of direction vector in Vertical direction:',comp_dir_vect_source_Z_UP(isource)

          write(IMAIN,*)
          write(IMAIN,*) '  nu1 = ',nu_source(1,:,isource)
          write(IMAIN,*) '  nu2 = ',nu_source(2,:,isource)
          write(IMAIN,*) '  nu3 = ',nu_source(3,:,isource)
          write(IMAIN,*)
          write(IMAIN,*) '  at (x,y,z) coordinates = ',x_found_source(isource),y_found_source(isource),z_found_source(isource)

          ! prints frequency content for point forces
          f0 = hdur(isource)
          t0_ricker = 1.2d0/f0
          write(IMAIN,*) '  using a source of dominant frequency ',f0
          write(IMAIN,*) '  lambda_S at dominant frequency = ',3000./sqrt(3.)/f0
          write(IMAIN,*) '  lambda_S at highest significant frequency = ',3000./sqrt(3.)/(2.5*f0)
          write(IMAIN,*) '  t0 = ',t0_ricker,'tshift_src = ',tshift_src(isource)
        else
          write(IMAIN,*) '  xi coordinate of source in that element: ',xi_source(isource)
          write(IMAIN,*) '  eta coordinate of source in that element: ',eta_source(isource)
          write(IMAIN,*) '  gamma coordinate of source in that element: ',gamma_source(isource)
        endif

        ! add message if source is a Heaviside
        if(hdur(isource) <= 5.*DT) then
          write(IMAIN,*)
          write(IMAIN,*) 'Source time function is a Heaviside, convolve later'
          write(IMAIN,*)
        endif

        write(IMAIN,*)
        if(USE_FORCE_POINT_SOURCE) then
          write(IMAIN,*) ' half duration -> frequency: ',hdur(isource),' seconds**(-1)'
        else
          write(IMAIN,*) ' half duration: ',hdur(isource),' seconds'
        endif
        write(IMAIN,*) '    time shift: ',tshift_src(isource),' seconds'

        write(IMAIN,*)
        write(IMAIN,*) 'original (requested) position of the source:'
        write(IMAIN,*)
        write(IMAIN,*) '          latitude: ',lat(isource)
        write(IMAIN,*) '         longitude: ',long(isource)
        write(IMAIN,*)
        write(IMAIN,*) '            cubed_sphere theta: ',theta_source(isource)
        write(IMAIN,*) '            cubed_sphere phi: ',phi_source(isource)
        write(IMAIN,*) '         depth: ',depth(isource),' km'
        write(IMAIN,*) 'topo elevation: ',elevation(isource)

        write(IMAIN,*)
        write(IMAIN,*) 'position of the source that will be used:'
        write(IMAIN,*)
        write(IMAIN,*) '         cubed_sphere x: ',x_found_source(isource)
        write(IMAIN,*) '         cubed_sphere y: ',y_found_source(isource)
        write(IMAIN,*) '         cubed_sphere z: ',z_found_source(isource)
        write(IMAIN,*)

        ! display error in location estimate
        write(IMAIN,*) 'error in location of the source: ',sngl(final_distance_source(isource)),' m'

        ! add warning if estimate is poor
        ! (usually means source outside the mesh given by the user)
        if(final_distance_source(isource) > 3000.d0) then
          write(IMAIN,*)
          write(IMAIN,*) '*****************************************************'
          write(IMAIN,*) '*****************************************************'
          write(IMAIN,*) '***** WARNING: source location estimate is poor *****'
          write(IMAIN,*) '*****************************************************'
          write(IMAIN,*) '*****************************************************'
        endif

      endif  ! end of detailed output to locate source

      if(PRINT_SOURCE_TIME_FUNCTION) then
        write(IMAIN,*)
        write(IMAIN,*) 'printing the source-time function'
      endif

      ! checks CMTSOLUTION format for acoustic case
      tinyMoment=max(abs(Mxx(isource)),abs(Myy(isource)),abs(Mzz(isource)), &
                     abs(Mxy(isource)),abs(Mxz(isource)),abs(Myz(isource)))*1.e-10
      if( idomain(isource) == IDOMAIN_ACOUSTIC ) then
        if( abs(Mxx(isource)- Myy(isource))>tinyMoment .or. abs(Myy(isource)- Mzz(isource))>tinyMoment.or. &
           Mxy(isource) > tinyMoment .or. Mxz(isource) > tinyMoment .or. Myz(isource) >tinyMoment ) then
            write(IMAIN,*) 'Mxx=',Mxx(isource),'Myy',Myy(isource),'Mzz',Mzz(isource), &
                             &'Mxy=',Mxy(isource),'Mxz',Mxz(isource),'Myz',Myz(isource),isource
            write(IMAIN,*) ' error CMTSOLUTION format for acoustic source:'
            write(IMAIN,*) '   acoustic source needs explosive moment tensor with'
            write(IMAIN,*) '      Mrr = Mtt = Mpp '
            write(IMAIN,*) '   and '
            write(IMAIN,*) '      Mrt = Mrp = Mtp = zero'
            write(IMAIN,*)
            call exit_mpi(myrank,'error acoustic source')
        endif
      endif

      ! checks source domain
      if( idomain(isource) /= IDOMAIN_ACOUSTIC .and. idomain(isource) /= IDOMAIN_ELASTIC ) then
        ! only acoustic/elastic domain implement yet
        call exit_MPI(myrank,'source located in unknown domain')
      endif

    ! end of loop on all the sources
    enddo
   else 
       print *,'COUPLING',COUPLING_TYPE
       call exit_MPI(myrank,'Error,COUPLING_TYPE must be 1,2,3 or 4!')
   end if

    ! display maximum error in location estimate
    write(IMAIN,*)
    write(IMAIN,*) 'maximum error in location of the sources: ',sngl(maxval(final_distance_source)),' m'
    write(IMAIN,*)

    ! sets new cubed_sphere coordinates for best locations
    cubed_x_source(:) = x_found_source(:)
    cubed_y_source(:) = y_found_source(:)

  endif     ! end of section executed by main process only

  ! main process broadcasts the results to all the slices
  call bcast_all_i(islice_selected_source,NSOURCES)
  call bcast_all_i(ispec_selected_source,NSOURCES)
  call bcast_all_dp(xi_source,NSOURCES)
  call bcast_all_dp(eta_source,NSOURCES)
  call bcast_all_dp(gamma_source,NSOURCES)
  call bcast_all_dp(cubed_x_source,NSOURCES)
  call bcast_all_dp(cubed_y_source,NSOURCES)

  ! elapsed time since beginning of source detection
  if(myrank == 0) then
    tCPU = wtime() - time_start
    write(IMAIN,*)
    write(IMAIN,*) 'Elapsed time for detection of sources in seconds = ',tCPU
    write(IMAIN,*)
    write(IMAIN,*) 'End of source detection - done'
    write(IMAIN,*)
  endif

  end subroutine locate_source_cubed

