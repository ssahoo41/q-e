!
! Copyright (C) 2002-2005 Quantum-ESPRESSO group
! This file is distributed under the terms of the
! GNU General Public License. See the file `License'
! in the root directory of the present distribution,
! or http://www.gnu.org/copyleft/gpl.txt .
!
#include "f_defs.h"
!
!----------------------------------------------------------------------------
SUBROUTINE cprmain( tau, fion_out, etot_out )
  !----------------------------------------------------------------------------
  !
  USE kinds,                    ONLY : dbl
  USE constants,                ONLY : bohr_radius_angs, uma_au
  USE control_flags,            ONLY : iprint, isave, thdyn, tpre, tbuff,      &
                                       iprsta, trhor, tfor, tvlocw, trhow,     &
                                       taurdr, tprnfor, tsdc, lconstrain, lwf, &
                                       lneb, lcoarsegrained, ndr, ndw, nomore, &
                                       tsde, tortho, tnosee, tnosep, trane,    &
                                       tranp, tsdp, tcp, tcap, ampre, amprp,   &
                                       tnoseh, tolp, ortho_eps, ortho_max,     &
                                       printwfc
  USE core,                     ONLY : nlcc_any, rhoc
  USE uspp_param,               ONLY : nhm, nh
  USE cvan,                     ONLY : nvb, ish
  USE uspp,                     ONLY : nkb, vkb, becsum, deeq
  USE energies,                 ONLY : eht, epseu, exc, etot, eself, enl, &
                                       ekin, atot, entropy, egrand, enthal, &
                                       ekincm, print_energies
  USE electrons_base,           ONLY : nbspx, nbsp, ispin => fspin, f, nspin
  USE electrons_base,           ONLY : nel, iupdwn, nupdwn, nudx, nelt
  USE efield_module,            ONLY : efield, epol, tefield, allocate_efield, &
                                       efield_update, ipolp, qmat, gqq,        &
                                       evalue, berry_energy
  USE ensemble_dft,             ONLY : tens, tgrand, ninner, ismear, etemp,   &
                                       ef, tdynz, tdynf, zmass, fmass, fricz, &
                                       fricf, allocate_ensemble_dft,          &
                                       id_matrix_init, z0, c0diag, becdiag,   &
                                       bec0, v0s, vhxcs, becdrdiag, gibbsfe
  USE cg_module,                ONLY : tcg, maxiter, etresh, passop, &
                                       allocate_cg, cg_update, &
                                       itercg, c0old
  USE gvecp,                    ONLY : ngm
  USE gvecs,                    ONLY : ngs
  USE gvecb,                    ONLY : ngb
  USE gvecw,                    ONLY : ngw
  USE reciprocal_vectors,       ONLY : gstart, mill_l
  USE ions_base,                ONLY : na, nat, pmass, nax, nsp, rcmax
  USE ions_base,                ONLY : ind_srt, ions_cofmass, ions_kinene, &
                                       ions_temp, ions_thermal_stress, if_pos
  USE ions_base,                ONLY : ions_vrescal, fricp, greasp, &
                                       iforce, ions_shiftvar, ityp, &
                                       atm, ind_bck, cdm, cdmi, fion, fionm
  USE cell_base,                ONLY : a1, a2, a3, b1, b2, b3, ainv, frich, &
                                       greash, tpiba2, omega, alat, ibrav,  &
                                       celldm, h, hold, hnew, velh, deth,   &
                                       wmass, press, iforceh, cell_force,   &
                                       thdiag
  USE grid_dimensions,          ONLY : nnrx, nr1, nr2, nr3
  USE smooth_grid_dimensions,   ONLY : nnrsx, nr1s, nr2s, nr3s
  USE smallbox_grid_dimensions, ONLY : nr1b, nr2b, nr3b
  USE local_pseudo,             ONLY : allocate_local_pseudo
  USE io_global,                ONLY : io_global_start, stdout, ionode
  USE mp_global,                ONLY : mp_global_start
  USE mp,                       ONLY : mp_sum, mp_barrier
  USE dener,                    ONLY : detot
  USE derho,                    ONLY : drhor, drhog
  USE cdvan,                    ONLY : dbec, drhovan
  USE stre,                     ONLY : stress
  USE gvecw,                    ONLY : ggp
  USE parameters,               ONLY : nacx, natx, nsx, nbndxx
  USE constants,                ONLY : pi, factem, au_gpa, au_ps, gpa_au
  USE io_files,                 ONLY : psfile, pseudo_dir
  USE wave_base,                ONLY : wave_steepest, wave_verlet
  USE wave_base,                ONLY : wave_speed2, frice, grease
  USE control_flags,            ONLY : conv_elec, tconvthrs
  USE check_stop,               ONLY : check_stop_now
  USE efcalc,                   ONLY : clear_nbeg, ef_force
  USE ions_base,                ONLY : zv, ions_vel
  USE cp_electronic_mass,       ONLY : emass, emass_cutoff, emass_precond
  USE ions_positions,           ONLY : tau0, taum, taup, taus, tausm, tausp, &
                                       vels, velsm, velsp, ions_hmove, ions_move
  USE ions_nose,                ONLY : gkbt, kbt, ndega, nhpcl, nhpdim, nhpend, qnp, &
                                       vnhp, xnhp0, xnhpm, xnhpp, atm2nhp, &
                                       ions_nosevel, ions_noseupd, &
                                       ions_nose_allocate, tempw,  &
                                       ions_nose_nrg, ions_nose_shiftvar, &
                                       gkbt2nhp, ekin2nhp, anum2nhp
  USE electrons_nose,           ONLY : qne, ekincw, xnhe0, xnhep, xnhem,  &
                                       vnhe, fccc, electrons_nose_nrg,    &
                                       electrons_nose_shiftvar,           &
                                       electrons_nosevel, electrons_noseupd
  USE from_scratch_module,      ONLY : from_scratch
  USE from_restart_module,      ONLY : from_restart
  USE wavefunctions_module,     ONLY : c0, cm, phi => cp
  USE wannier_module,           ONLY : allocate_wannier
  USE printout_base,            ONLY : printout_base_open, &
                                       printout_base_close, &
                                       printout_pos, printout_cell, &
                                       printout_stress
  USE cell_nose,                ONLY : xnhh0, xnhhm, xnhhp, vnhh, temph, &
                                       qnh, cell_nosevel, cell_noseupd,  &
                                       cell_nose_nrg, cell_nose_shiftvar
  USE cell_base,                ONLY : cell_kinene, cell_gamma, &
                                       cell_move, cell_hmove
  USE gvecw,                    ONLY : ecutw
  USE gvecp,                    ONLY : ecutp
  USE time_step,                ONLY : delt, tps, dt2, dt2by2, twodelt
  USE electrons_module,         ONLY : cp_eigs
  USE print_out_module,         ONLY : cp_print_rho
  USE cp_main_variables,        ONLY : allocate_mainvar, &
                                       acc, bec, lambda, lambdam, lambdap, &
                                       ema0bg, sfac, eigr, ei1, ei2, ei3,  &
                                       irb, becdr, taub, eigrb, rhog, rhos, &
                                       rhor, bephi, becp, nfi
  !
  USE cell_base,                ONLY : s_to_r, r_to_s
  USE phase_factors_module,     ONLY : strucf
  USE cpr_subroutines,          ONLY : print_lambda, print_atomic_var, &
                                       ions_cofmsub, elec_fakekine
  USE wannier_subroutines,      ONLY : wannier_startup, wf_closing_options, &
                                       ef_enthalpy
  USE restart_file,             ONLY : readfile, writefile
  USE constraints_module,       ONLY : check_constraint, lagrange
  USE coarsegrained_vars,       ONLY : dfe_acc
  !
  IMPLICIT NONE
  !
  ! ... input/output variables
  !
  REAL(KIND=dbl), INTENT(INOUT) :: tau(3,nat)
  REAL(KIND=dbl), INTENT(OUT)   :: fion_out(3,nat)
  REAL(KIND=dbl), INTENT(OUT)   :: etot_out
  !
  ! ... control variables
  !
  LOGICAL :: tfirst, tlast, tstop, tconv
  LOGICAL :: ttprint    
    !  logical variable used to control printout
  !
  ! ... forces on ions
  !
  REAL(KIND=dbl) :: maxfion
  !
  ! ... work variables
  !
  REAL(KIND=dbl) :: tempp, savee, saveh, savep, epot, epre, &
                    enow, econs, econt, ettt, ccc, bigr, dt2bye
  REAL(KIND=dbl) :: ekinc0, ekinp, ekinpr, ekinc
  REAL(KIND=dbl) :: temps(nsx)
  REAL(KIND=dbl) :: ekinh, temphc, temp1, temp2, randy
  REAL(KIND=dbl) :: delta_etot
  REAL(KIND=dbl) :: ftmp, enb, enbi
  INTEGER        :: is, nacc, ia, j, iter, i, isa, ipos
  INTEGER        :: k, ii, l, m
  !
  REAL(KIND=dbl) :: hgamma(3,3), temphh(3,3)
  REAL(KIND=dbl) :: fcell(3,3)
  !
  REAL(KIND=dbl) :: stress_gpa(3,3), thstress(3,3)
  !
  REAL(KIND=dbl), ALLOCATABLE :: tauw(:,:)  
    ! temporary array used to printout positions
  CHARACTER(LEN=3) :: labelw( natx )
  !
  !
  dt2bye   = dt2 / emass
  etot_out = 0.D0
  !
  tfirst   = .TRUE.
  tlast    = .FALSE.
  nacc     = 5
  !
  !======================================================================
  !
  !           basic loop for molecular dynamics starts here
  !
  !======================================================================
  !
  main_loop: DO
     !
     CALL start_clock( 'total_time' )
     !
     nfi     = nfi + 1
     tlast   = ( nfi == nomore )
     ttprint = ( MOD( nfi, iprint ) == 0 )
     !
     IF ( ionode .AND. ttprint ) &
        WRITE( stdout, '(/," * Physical Quantities at step:",I6)' ) nfi
     !
     ! ... calculation of velocity of nose-hoover variables
     !
     IF ( .NOT. tsde ) fccc = 1.D0 / ( 1.D0 + frice )
     !
     IF ( tnosep ) CALL ions_nosevel( vnhp, xnhp0, xnhpm, delt, nhpcl, nhpdim )
     !
     IF ( tnosee ) THEN
        !
        CALL electrons_nosevel( vnhe, xnhe0, xnhem, delt )
        !
        fccc = 1.D0 / ( 1.D0 + 0.5D0 * delt * vnhe )
        !
     END IF
     !
     IF ( tnoseh ) THEN
        !
        CALL cell_nosevel( vnhh, xnhh0, xnhhm, delt )
        !
        velh(:,:) = 2.D0 * ( h(:,:) - hold(:,:) ) / delt - velh(:,:)
        !
     END IF
     ! 
     IF ( tfor .OR. thdyn .OR. tfirst ) THEN
        !
        CALL initbox( tau0, taub, irb )
        CALL phbox( taub, eigrb )
        !
     END IF
     !
     IF ( tfor .OR. thdyn ) CALL phfac( tau0, ei1, ei2, ei3, eigr ) 
     !
     ! ... strucf calculates the structure factor sfac
     !
     CALL strucf( sfac, ei1, ei2, ei3, mill_l, ngs )
     !
     IF ( thdyn ) CALL formf( tfirst, eself )
     !
     ! ... why this call ??? from Paolo Umary
     !
     IF ( tefield ) CALL calbec( 1, nsp, eigr, c0, bec ) ! ATTENZIONE  
     !
     IF ( ( tfor .OR. tfirst ) .AND. tefield ) CALL efield_update( eigr )
     !
     !=======================================================================
     !
     !    electronic degrees of freedom are updated here
     !
     !=======================================================================
     !
     CALL move_electrons( nfi, tfirst, tlast, b1, b2, b3, fion, &
                          enthal, enb, enbi, fccc, ccc, dt2bye )
     !
     IF ( tpre ) THEN
        !
        CALL nlfh( bec, dbec, lambda )
        !
        CALL ions_thermal_stress( stress, pmass, omega, h, vels, nsp, na )
        !
     END IF
     !
     !=======================================================================
     !
     !              verlet algorithm
     !
     !     loop which updates cell parameters and ionic degrees of freedom
     !     hnew=h(t+dt) is obtained from hold=h(t-dt) and h=h(t)
     !     tausp=pos(t+dt) from tausm=pos(t-dt) taus=pos(t) h=h(t)
     !
     !           guessed displacement of ions
     !=======================================================================
     !
     hgamma(:,:) = 0.D0
     !
     IF ( thdyn ) THEN
        !
        CALL cell_force( fcell, ainv, stress, omega, press, wmass )
        !
        CALL cell_move( hnew, h, hold, delt, iforceh, &
                        fcell, frich, tnoseh, vnhh, velh, tsdc )
        !
        velh(:,:) = ( hnew(:,:) - hold(:,:) ) / twodelt
        !
        CALL cell_gamma( hgamma, ainv, h, velh )
        !
     END IF
     !
     !======================================================================
     !
     IF ( tfor ) THEN
        !
        IF ( lwf ) CALL ef_force( fion, na, nsp, zv )
        !
        CALL ions_move( tausp, taus, tausm, iforce, pmass, fion,  &
                        ainv, delt, na, nsp, fricp, hgamma, vels, &
                        tsdp, tnosep, fionm, vnhp, velsp, velsm,  &
                        nhpcl, nhpdim, atm2nhp )
        !
        IF ( lconstrain ) THEN
           !
           ! ... constraints are imposed here
           !
           CALL s_to_r( tausp, taup, na, nsp, hnew )
           !
           CALL check_constraint( nat, taup, tau0, &
                                  fion, iforce, ityp, 1.D0, delt, uma_au )
           !
           CALL r_to_s( taup, tausp, na, nsp, ainv )
           !
           ! ... average value of the lagrange multipliers
           !
           IF ( lcoarsegrained ) dfe_acc(:,1) = dfe_acc(:,1) - lagrange(:)
           !
        END IF
        !
        CALL ions_cofmass( tausp, pmass, na, nsp, cdm )
        !
        CALL ions_cofmsub( tausp, iforce, na, nsp, cdm, cdmi )
        !
        CALL s_to_r( tausp, taup, na, nsp, hnew )
        !
     END IF
     !     
     !--------------------------------------------------------------------------
     !              initialization with guessed positions of ions
     !--------------------------------------------------------------------------
     !
     ! ... if thdyn=true g vectors and pseudopotentials are recalculated for 
     ! ... the new cell parameters
     !
     IF ( tfor .OR. thdyn ) THEN
        !
        IF ( thdyn ) THEN
           !
           hold = h
           h    = hnew
           !
           CALL newinit( h )
           CALL newnlinit()
           !
        ELSE
           !
           hold = h
           !
        END IF
        !
        ! ... phfac calculates eigr
        !
        CALL phfac( taup, ei1, ei2, ei3, eigr )
        !
        ! ... prefor calculates vkb
        !
        CALL prefor( eigr, vkb )
        !
     END IF
     !
     !--------------------------------------------------------------------------
     !                    imposing the orthogonality
     !--------------------------------------------------------------------------
     !
     IF ( .NOT. tcg ) THEN
        !
        IF ( tortho ) THEN
           !
           CALL ortho( eigr, cm, phi, lambda, bigr, iter, ccc, &
                       ortho_eps, ortho_max, delt, bephi, becp )
           !
        ELSE
           !
           CALL gram( vkb, bec,cm )
           !
           IF ( iprsta > 4 ) CALL dotcsc( eigr, cm )
           !
        END IF
        !
     END IF
     !
     !--------------------------------------------------------------------------
     !                   correction to displacement of ions
     !--------------------------------------------------------------------------
     !
     IF ( .NOT. tcg ) THEN
        !
        IF ( iprsta >= 3 ) CALL print_lambda( lambda, nbsp, 9, 1.D0 )
        !
        IF ( tortho ) CALL updatc( ccc, lambda, phi, bephi, becp, bec, cm )
        !
        CALL calbec( nvb+1, nsp, eigr, cm, bec )
        !
        IF ( tpre ) &
           CALL caldbec( ngw, nkb, nbsp, 1, nsp, eigr, cm, dbec, .TRUE. )
        !
        IF ( iprsta >= 3 ) CALL dotcsc( eigr, cm )
        !
     END IF
     !
     !--------------------------------------------------------------------------
     !                  temperature monitored and controlled
     !--------------------------------------------------------------------------
     !
     ekinp  = 0.D0
     ekinpr = 0.D0
     tempp  = 0.D0
     ekinc0 = 0.0d0
     ekinc = 0.0d0
     !
     !
     ! ... ionic kinetic energy 
     !
     IF ( tfor ) THEN
        !
        CALL ions_vel( vels, tausp, tausm, na, nsp, delt )
        !
        CALL ions_kinene( ekinp, vels, na, nsp, hold, pmass )
        !
     END IF
     !
     ! ... ionic temperature
     !
     IF ( tfor ) &
        CALL ions_temp( tempp, temps, ekinpr, vels, na, nsp, &
                        hold, pmass, ndega, nhpdim, atm2nhp, ekin2nhp )
     !
     ! ... fake electronic kinetic energy
     !
     IF ( .NOT. tcg ) THEN
        !
        CALL elec_fakekine( ekinc0, ema0bg, emass, c0, cm, ngw, nbsp, delt )
        !
        ekinc = ekinc0
        !
     END IF
     
     !
     ! ... fake cell-parameters kinetic energy
     !
     ekinh = 0.D0
     !
     IF ( thdyn ) CALL cell_kinene( ekinh, temphh, velh )
     !
     IF ( COUNT( iforceh == 1 ) > 0 ) THEN
        !
        temphc = 2.D0 * factem * ekinh / DBLE( COUNT( iforceh == 1 ) )
        !
     ELSE
        !
        temphc = 0.D0
        !
     END IF
     !
     ! ... udating nose-hoover friction variables
     !
     IF ( tnosep ) CALL ions_noseupd( xnhpp, xnhp0, xnhpm, delt, qnp, &
                                      ekin2nhp, gkbt2nhp, vnhp, kbt,  &
                                      nhpcl, nhpdim, nhpend )
     !
     IF ( tnosee ) CALL electrons_noseupd( xnhep, xnhe0, xnhem, &
                                           delt, qne, ekinc, ekincw, vnhe )
     !
     IF ( tnoseh ) CALL cell_noseupd( xnhhp, xnhh0, xnhhm, &
                                      delt, qnh, temphh, temph, vnhh )
     !
     ! ... warning:  thdyn and tcp/tcap are not compatible yet!!!
     !
     IF ( tcp .OR. tcap .AND. tfor .AND. .NOT.thdyn ) THEN
        !
        IF ( tempp > temp1 .OR. tempp < temp2 .AND. tempp /= 0.D0 ) THEN
           !
           CALL  ions_vrescal( tcap, tempw, tempp, taup, &
                               tau0, taum, na, nsp, fion, iforce, pmass, delt )
           !
        END IF
        !
     END IF
     !
     IF( ( MOD(nfi,iprint) == 0 ) .OR. ( nfi == nomore ) ) THEN
        !
        CALL cp_eigs( nfi, bec, c0, irb, eigrb, rhor, &
                      rhog, rhos, lambdap, lambda, tau0, h )
        !
        IF ( printwfc >= 0 ) &
           CALL cp_print_rho( nfi, bec, c0, eigr, irb, eigrb, rhor, &
                              rhog, rhos, lambdap, lambda, tau0, h )
        !
     END IF
     !
     IF ( lwf ) CALL ef_enthalpy( enthal, tau0 )
     !
     IF ( tens ) THEN
        !
        IF ( MOD( nfi, iprint ) == 0 .OR. ( nfi == nomore ) ) THEN
           !
           WRITE( stdout, '("Occupations  :")' )
           WRITE( stdout, '(10F9.6)' ) ( f(i), i = 1, nbsp )
           !
        END IF
        !
     END IF
     !
     epot = eht + epseu + exc
     !
     acc(1) = acc(1) + ekinc
     acc(2) = acc(2) + ekin
     acc(3) = acc(3) + epot
     acc(4) = acc(4) + etot
     acc(5) = acc(5) + tempp
     !
     IF ( .NOT. tcg ) THEN
        !
        econs = ekinp + ekinh + enthal
        econt = econs + ekinc
        !
     ELSE
        !
        IF ( .NOT. tens ) THEN
           !
           econs = ekinp + etot
           atot  = etot
           econt = econs
           !
        ELSE
           !
           gibbsfe = atot
           econs   = ekinp + atot
           econt   = econs
           !
        END IF
        !
     END IF
     !
     ! ... add energies of thermostats
     !
     IF ( tnosep ) &
        econt = econt + ions_nose_nrg( xnhp0, vnhp, qnp, &
                                       gkbt2nhp, kbt, nhpcl, nhpdim )
     IF ( tnosee ) &
        econt = econt + electrons_nose_nrg( xnhe0, vnhe, qne, ekincw )
     IF ( tnoseh ) &
        econt = econt + cell_nose_nrg( qnh, xnhh0, vnhh, temph, iforceh )
     !
     IF ( ionode .AND. ttprint ) THEN
        !
        ! ... Open units 30, 31, ... 40 for simulation output
        !
        CALL printout_base_open()
        !
        CALL print_energies( .false. )
        !
        WRITE( stdout, * )
        !
        CALL printout_cell( stdout, hold )
        CALL printout_cell( 36, hold, nfi, tps )
        !
        WRITE( stdout, * )
        !
        stress_gpa = stress * au_gpa
        !
        CALL printout_stress( stdout, stress_gpa )
        CALL printout_stress( 38, stress_gpa, nfi, tps )
        !
        WRITE( stdout, * )
        !
        ! ... write out a standard XYZ file in angstroms
        !
        labelw(ind_bck(1:nat)) = atm(ityp(1:nat))
        !
        CALL printout_pos( stdout, tau0, nat, &
                           what = 'pos', label = labelw, sort = ind_bck )
        CALL printout_pos( 35, tau0, nat, nfi = nfi, tps = tps )
        !
        ALLOCATE( tauw( 3, natx ) )
        !
        isa = 0 
        !
        DO is = 1, nsp
           !
           DO ia = 1, na(is)
              !
              isa = isa + 1
              !
              CALL s_to_r( vels(:,isa), tauw(:,isa), hold )
              !
           END DO
           !
        END DO
        !
        WRITE( stdout, * )
        !
        CALL printout_pos( stdout, tauw, nat, &
                           what = 'vel', label = labelw, sort = ind_bck )
        CALL printout_pos( 34, tauw, nat, nfi = nfi, tps = tps )
        !
        WRITE( stdout, * )
        !
        CALL printout_pos( stdout, fion, nat, &
                           what = 'for', label = labelw, sort = ind_bck )
        CALL printout_pos( 37, fion, nat, nfi = nfi, tps = tps )
        !
        DEALLOCATE( tauw )
        !
        WRITE( 33, 2948 ) tps, ekinc, temphc, tempp, etot, enthal, econs, econt
        WRITE( 39, 2949 ) tps, vnhh(3,3), xnhh0(3,3), vnhp(1), xnhp0(1)
        !
        ! ... Close and flush unit 30, ... 40
        !
        CALL printout_base_close()
        !
     END IF
     !
10   FORMAT( /,3X,'Cell Variables (AU)',/ )
11   FORMAT( /,3X,'Atomic Positions (AU)',/ )
12   FORMAT( /,3X,'Atomic Velocities (AU)',/ )
13   FORMAT( /,3X,'Atomic Forces (AU)',/ )
17   FORMAT( /,3X,'Total Stress (GPa)',/ )
255  FORMAT( '     ',5(1X,A12) )
256  FORMAT( 'Step ',I5,1X,I7,1X,F12.5,1X,F12.5,1X,F12.5,1X,I5 )
2948 FORMAT( F8.5,1X,F8.5,1X,F6.1,1X,F6.1,3(1X,F11.5) )
2949 FORMAT( F8.5,1X,4(1X,F7.4) )
     !
     IF( ( MOD( nfi, iprint ) == 0 ) .OR. tfirst )  THEN
        !
        WRITE( stdout, * )
        WRITE( stdout, 1947 )
        !
     END IF
     !
     WRITE( stdout, 1948 ) nfi, ekinc, temphc, tempp, etot, enthal, econs, &
                           econt, vnhh(3,3), xnhh0(3,3), vnhp(1),  xnhp0(1)
     !
     IF( tcg ) THEN
        !
        IF ( MOD( nfi, iprint ) == 0 .OR. tfirst ) THEN
           !
           WRITE( stdout, * )
           WRITE( stdout, 255 ) 'nfi','tempp','E','-T.S-mu.nbsp','+K_p'
           !
        END IF
        !
        WRITE( stdout, 256 ) nfi, INT( tempp ), etot, atot, econs, itercg
        !
     END IF
     !
1947 FORMAT( 2X,'nfi',4X,'ekinc',2X,'temph',2X,'tempp',8X,'etot',6X,'enthal', &
           & 7X,'econs',7X,'econt',4X,'vnhh',3X,'xnhh0',4X,'vnhp',3X,'xnhp0' )
1948 FORMAT( I5,1X,F8.5,1X,F6.1,1X,F6.1,4(1X,F11.5),4(1X,F7.4) )
     !
     !
     tps = tps + delt * au_ps
     !
     IF( tfor ) THEN
        !
        ! ... new variables for next step
        !
        CALL ions_shiftvar( taup,  tau0, taum  )   !  real positions
        CALL ions_shiftvar( tausp, taus, tausm )   !  scaled positions         
        CALL ions_shiftvar( velsp, vels, velsm )   !  scaled velocities
        !
        IF ( tnosep ) CALL ions_nose_shiftvar( xnhpp, xnhp0, xnhpm )
        IF ( tnosee ) CALL electrons_nose_shiftvar( xnhep, xnhe0, xnhem )
        IF ( tnoseh ) CALL cell_nose_shiftvar( xnhhp, xnhh0, xnhhm )
        !
     END IF
     !
     IF ( thdyn ) CALL emass_precond( ema0bg, ggp, ngw, tpiba2, emass_cutoff )
     !
     ekincm = ekinc0
     !  
     ! ... cm=c(t+dt) c0=c(t)
     !
     IF( .NOT. tcg ) THEN
        !
        CALL dswap( 2*ngw*nbsp, c0, 1, cm, 1 )
        !
     ELSE
        !
        CALL cg_update( tfirst, nfi, c0 )
        !
     END IF
     !
     ! ... now:  cm=c(t) c0=c(t+dt)
     !
     IF ( tfirst ) THEN
        !
        epre = etot
        enow = etot
        !
     END IF
     !
     tfirst = .FALSE.
     !
     ! ... write on file ndw each isave
     !
     IF ( ( MOD( nfi, isave ) == 0 ) .AND. ( nfi < nomore ) ) THEN
        !
        IF ( tcg ) THEN
           !
           CALL writefile( ndw, h, hold ,nfi, c0(:,:,1,1), c0old, taus, tausm, &
                           vels, velsm, acc, lambda, lambdam, xnhe0, xnhem,    &
                           vnhe, xnhp0, xnhpm, vnhp, nhpcl, ekincm, xnhh0,     &
                           xnhhm, vnhh, velh, ecutp, ecutw, delt, pmass, ibrav,&
                           celldm, fion, tps, z0, f )
           !
        ELSE
           !
           CALL writefile( ndw, h, hold, nfi, c0(:,:,1,1), cm(:,:,1,1), taus,  &
                           tausm, vels, velsm, acc,  lambda, lambdam, xnhe0,   &
                           xnhem, vnhe, xnhp0, xnhpm, vnhp, nhpcl, ekincm,     &
                           xnhh0, xnhhm, vnhh, velh, ecutp, ecutw, delt, pmass,&
                           ibrav, celldm, fion, tps, z0, f )
           !
        END IF
        !
     END IF
     !
     epre = enow
     enow = etot
     !
     frice = frice * grease
     fricp = fricp * greasp
     frich = frich * greash
     !
     !======================================================================
     !
     CALL stop_clock( 'total_time' )
     !
     delta_etot = ABS( epre - enow )
     !
     tstop = check_stop_now()
     tconv = .FALSE.
     !
     IF ( tconvthrs%active ) THEN
        !
        ! ... electrons
        !
        tconv = ( ekinc < tconvthrs%ekin .AND. delta_etot < tconvthrs%derho )
        !
        IF ( tfor ) THEN
           !
           ! ... ions
           !
           maxfion = MAXVAL( ABS( fion(:,1:nat) ) )
           !
           tconv = tconv .AND. ( maxfion < tconvthrs%force )
           !
        END IF
        !
     END IF
     !
     ! ... in the case cp-wf the check on convergence is done starting
     ! ... from the second step 
     !
     IF ( lwf .AND. tfirst ) tconv = .FALSE.
     !
     IF ( tconv ) THEN
        !
        IF ( ionode ) THEN
           !
           WRITE( stdout, &
                & "(/,3X,'MAIN:',10X,'EKINC   (thr)', &
                & 10X,'DETOT   (thr)',7X,'MAXFORCE   (thr)')" )
           WRITE( stdout, "(3X,'MAIN: ',3(D14.6,1X,D8.1))" ) &
               ekinc, tconvthrs%ekin, delta_etot,                  &
               tconvthrs%derho, 0.D0, tconvthrs%force
           WRITE( stdout, &
                  "(3X,'MAIN: convergence achieved for system relaxation')" )
           !
        END IF
        !
     END IF
     !
     tstop = tstop .OR. tconv
     !
     IF ( lwf ) &
        CALL wf_closing_options( nfi, c0, cm, bec, becdr, eigr, eigrb, taub, &
                                 irb, ibrav, b1, b2, b3, taus, tausm, vels,  &
                                 velsm, acc, lambda, lambdam, xnhe0, xnhem,  &
                                 vnhe, xnhp0, xnhpm, vnhp, nhpcl, ekincm,    &
                                 xnhh0, xnhhm, vnhh, velh, ecutp, ecutw,     &
                                 delt, celldm, fion, tps, z0, f )
     !
     IF ( ( nfi >= nomore ) .OR. tstop ) EXIT main_loop
     !
  END DO main_loop
  !
  !===================== end of main loop of molecular dynamics ===============
  ! 
  ! ... Here copy relevant physical quantities into the output arrays/variables
  !
  etot_out = etot
  !
  isa = 0
  !
  DO is = 1, nsp
     !
     DO ia = 1, na(is)
        !
        isa = isa + 1
        !
        ipos = ind_srt( isa )
        !
        tau(:,ipos) = tau0(:,isa)
        !
        fion_out(:,ipos) = fion(:,isa)
        !
     END DO
     !
  END DO
  !
  IF ( lneb ) fion_out(:,1:nat) = fion(:,1:nat) * DBLE( if_pos(:,1:nat) )
  !
  ! ...  Calculate statistics
  !
  acc = acc / DBLE( nfi )
  !
  IF ( ionode ) THEN
     !
     WRITE( stdout, 1949 )
     WRITE( stdout, 1950 ) ( acc(i), i = 1, nacc )
     !
  END IF
  !
1949 FORMAT( //'              averaged quantities :',/,9X,&
           & 'ekinc',10X,'ekin',10X,'epot',10X,'etot',5X,'tempp' )
1950 FORMAT( 4F14.5,F10.1 )
  !
  CALL print_clock( 'initialize' )
  CALL print_clock( 'total_time' )
  CALL print_clock( 'formf' )
  CALL print_clock( 'rhoofr' )
  CALL print_clock( 'vofrho' )
  CALL print_clock( 'dforce' )
  CALL print_clock( 'calphi' )
  CALL print_clock( 'ortho' )
  CALL print_clock( 'updatc' )
  CALL print_clock( 'gram' )
  CALL print_clock( 'newd' )
  CALL print_clock( 'calbec' )
  CALL print_clock( 'prefor' )
  CALL print_clock( 'strucf' )
  CALL print_clock( 'nlfl' )
  CALL print_clock( 'nlfq' )
  CALL print_clock( 'set_cc' )
  CALL print_clock( 'rhov' )
  CALL print_clock( 'nlsm1' )
  CALL print_clock( 'nlsm2' )
  CALL print_clock( 'forcecc' )
  CALL print_clock( 'fft' )
  CALL print_clock( 'ffts' )
  CALL print_clock( 'fftw' )
  CALL print_clock( 'fftb' )
  CALL print_clock( 'rsg' )
  CALL print_clock( 'reduce' )
  !
  IF ( tcg ) THEN
     !
     CALL writefile( ndw, h, hold, nfi, c0(:,:,1,1), c0old, taus, tausm, vels, &
                     velsm, acc, lambda, lambdam, xnhe0, xnhem, vnhe, xnhp0,   &
                     xnhpm, vnhp, nhpcl, ekincm, xnhh0, xnhhm, vnhh, velh,     &
                     ecutp, ecutw, delt, pmass, ibrav, celldm, fion, tps,      &
                     z0, f )
     !
  ELSE
     !
     CALL writefile( ndw, h, hold, nfi, c0(:,:,1,1), cm(:,:,1,1), taus, tausm, &
                     vels, velsm, acc, lambda, lambdam, xnhe0, xnhem, vnhe,    &
                     xnhp0, xnhpm, vnhp, nhpcl, ekincm, xnhh0, xnhhm, vnhh,    &
                     velh, ecutp, ecutw, delt, pmass, ibrav, celldm, fion, tps,&
                     z0, f )
     !
  END IF
  !
  IF( iprsta > 1 ) CALL print_lambda( lambda, nbsp, nbsp, 1.D0 )
  !
  conv_elec = .TRUE.
  !
1974 FORMAT( 1X,2I5,3F10.4,2X,3F10.4 )
1975 FORMAT( /1X,'Scaled coordinates '/1X,'species',' atom #' )
1976 FORMAT( 1X,2I5,3F10.4 )
  !
  IF ( ionode ) &
     WRITE( stdout, '(5X,//,24("=")," end cp ",24("="),//)' ) 
  !
  CALL memory()
  !
  RETURN
  !
END SUBROUTINE cprmain
