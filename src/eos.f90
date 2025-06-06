!> Interface to thermodynamic models.
!!
!! \author MH, 2012-01-25
module eos
  use thermopack_constants
  use thermopack_var, only: nc, get_active_thermo_model, thermo_model, &
       get_active_eos, get_active_alt_eos, base_eos_param, Rgas
  !
  implicit none
  save
  !
  private
  public :: thermo
  public :: zfac, entropy, enthalpy, specificVolume, molardensity, pseudo
  public :: pseudo_safe
  public :: twoPhaseEnthalpy, twoPhaseEntropy, twoPhaseSpecificVolume
  public :: twoPhaseInternalEnergy
  public :: moleWeight, compMoleWeight, getCriticalParam
  public :: residualGibbs
  public :: ideal_gibbs_single, ideal_enthalpy_single, ideal_entropy_single
  !
contains

  !----------------------------------------------------------------------
  !> Calculate fugasity coefficient and differentials given composition,
  !> temperature and pressure
  !>
  !> \author MH, 2012-01-27
  !----------------------------------------------------------------------
  subroutine thermo(t,p,z,phase,lnfug,lnfugt,lnfugp,lnfugx,ophase,metaExtremum,v)
    use single_phase, only: TP_CalcFugacity, TP_CalcZfac
    use numconstants, only: machine_prec
    implicit none
    ! Transferred variables
    integer, intent(in)                               :: phase !< Phase identifyer
    integer, optional, intent(out)                    :: ophase !< Phase identifyer for MINGIBBSPH
    real, intent(in)                                  :: t !< K - Temperature
    real, intent(in)                                  :: p !< Pa - Pressure
    real, dimension(1:nc), intent(in)                 :: z !< Compozition
    real, dimension(1:nc), intent(out)                :: lnfug !< Logarithm of fugasity coefficient
    real, optional, dimension(1:nc), intent(out)      :: lnfugt !< 1/K - Logarithm of fugasity coefficient differential wrpt. temperature
    real, optional, dimension(1:nc), intent(out)      :: lnfugp !< 1/Pa - Logarithm of fugasity coefficient differential wrpt. pressure
    real, optional, dimension(1:nc,1:nc), intent(out) :: lnfugx !< Logarithm of fugasity coefficient differential wrpt. mole numbers
    logical, optional, intent(in)                     :: metaExtremum
    real, optional, intent(out)                       :: v !< Specific volume [mol/m3]
    ! Locals
    real, dimension(1:nc) :: x, lnfugt2, lnfugp2
    real, dimension(nc*(nc+3)) :: tp_fug, g_tp_fug
    real, dimension(nc,nc) :: lnfugx2
    real :: gLiq, gVap, v2
    integer :: gflag_opt, ph
    type(thermo_model), pointer :: act_mod_ptr
    class(base_eos_param), pointer :: act_eos_ptr
    !
    !--------------------------------------------------------------------
    x = z(1:nc)/sum(z(1:nc))

    ph = phase
    if (ph == SINGLEPH) then
      ph = LIQPH
    endif

    act_mod_ptr => get_active_thermo_model()
    act_eos_ptr => get_active_eos()
    gflag_opt = 1
    if (present(metaExtremum)) then
      if (metaExtremum) then
        gflag_opt = 2
      endif
    endif
    if (ph == LIQPH .OR. ph == VAPPH) then
      call TP_CalcFugacity(nc,act_mod_ptr%comps,act_eos_ptr,&
           t,p,x,ph,tp_fug,lnfugt,lnfugp,lnfugx,gflag_opt,v=v)
    else if (ph == MINGIBBSPH) then
      call TP_CalcFugacity(nc,act_mod_ptr%comps,act_eos_ptr,&
           t,p,x,LIQPH,g_tp_fug,lnfugt,lnfugp,lnfugx,gflag_opt,v=v,phase_found=ophase)
      if (ophase == FAKEPH) return
      if (present(lnfugt)) then
        lnfugt2 = lnfugt
      endif
      if (present(lnfugp)) then
        lnfugp2 = lnfugp
      endif
      if (present(lnfugx)) then
        lnfugx2 = lnfugx
      endif
      if (present(v)) then
        v2 = v
      endif
      call TP_CalcFugacity(nc,act_mod_ptr%comps,act_eos_ptr,&
           t,p,x,VAPPH,tp_fug,lnfugt,lnfugp,lnfugx,gflag_opt,v=v)

      gVap = sum(x*tp_fug(1:nc))
      gLiq = sum(x*g_tp_fug(1:nc))
      if (present(ophase)) then
        ophase = VAPPH
      endif

      if (abs(gLiq-gVap)/abs(gLiq) < 100.0*machine_prec) then
        if (present(ophase)) then
          ophase = SINGLEPH
        endif
      else if (gLiq < gVap) then
        if (present(ophase)) then
          ophase = LIQPH
        endif
        tp_fug(1:nc) = g_tp_fug(1:nc)
        if (present(lnfugt)) then
          lnfugt = lnfugt2
        endif
        if (present(lnfugp)) then
          lnfugp = lnfugp2
        endif
        if (present(lnfugx)) then
          lnfugx = lnfugx2
        endif
        if (present(v)) then
          v = v2
        endif
      endif
    endif
    lnfug = tp_fug(1:nc)
  end subroutine thermo

  !----------------------------------------------------------------------
  !> Calculate single-phase compressibility factor given composition,
  !> temperature and pressure
  !>
  !> \author MH, 2012-03-20
  !----------------------------------------------------------------------
  subroutine zfac(t,p,x,phase,z,dzdt,dzdp,dzdx)
    use single_phase, only: TP_CalcZfac
    implicit none
    ! Transferred variables
    integer, intent(in) :: phase !< Phase identifyer
    real, intent(in) :: t !< K - Temperature
    real, intent(in) :: p !< Pa - Pressure
    real, dimension(1:nc), intent(in) :: x !< Compozition
    real, intent(out) :: z !< Compressibillity factor
    real, optional, intent(out) :: dzdt !< 1/K - Compressibillity factor differential wrpt. temperature
    real, optional, intent(out) :: dzdp !< 1/Pa - Compressibillity factor differential wrpt. pressure
    real, optional, dimension(1:nc), intent(out) :: dzdx !< Compressibillity factor differential wrpt. mole numbers
    ! Locals
    real, dimension(1:nc) :: xx
    type(thermo_model), pointer :: act_mod_ptr
    class(base_eos_param), pointer :: act_eos_ptr
    !
    !--------------------------------------------------------------------
    xx = x(1:nc)/sum(x(1:nc))
    act_mod_ptr => get_active_thermo_model()
    act_eos_ptr => get_active_eos()
    z = TP_CalcZfac(nc,act_mod_ptr%comps,act_eos_ptr,&
         t,p,xx,phase,1,dzdt,dzdp,dzdx)
  end subroutine zfac

  !----------------------------------------------------------------------
  !> Calculate single-phase specific volume given composition, temperature and
  !> pressure
  !>
  !> \author MH, 2012-07-06
  !----------------------------------------------------------------------
  subroutine specificVolume(t,p,x,phase,v,dvdt,dvdp,dvdx)
    use single_phase, only: TP_CalcZfac
    implicit none
    ! Transferred variables
    integer, intent(in) :: phase !< Phase identifyer
    real, intent(in) :: t !< K - Temperature
    real, intent(in) :: p !< Pa - Pressure
    real, dimension(1:nc), intent(in) :: x !< Compozition
    real, intent(out) :: v !< m3/mol - Specific volume
    real, optional, intent(out) :: dvdt !< m3/mol/K - Specific volume differential wrpt. temperature
    real, optional, intent(out) :: dvdp !< m3/mol/Pa - Specific volume differential wrpt. pressure
    real, optional, dimension(1:nc), intent(out) :: dvdx !< m3/mol - Specific volume differential wrpt. mole numbers
    ! Locals
    real, dimension(1:nc) :: xx
    real :: z
    integer :: ph
    type(thermo_model), pointer :: act_mod_ptr
    class(base_eos_param), pointer :: act_eos_ptr
    !
    !--------------------------------------------------------------------
    xx = x(1:nc)/sum(x(1:nc))
    act_mod_ptr => get_active_thermo_model()
    ph = phase
    if (ph == SINGLEPH) then
      ph = LIQPH
    endif

    act_eos_ptr => get_active_eos()
    z = TP_CalcZfac(nc,act_mod_ptr%comps,act_eos_ptr,&
         t,p,xx,ph,1,dvdt,dvdp,dvdx)
    v = z*Rgas*t/p
    if (present(dvdt)) then
      dvdt = dvdt*Rgas*t/p + v/t
    endif
    if (present(dvdp)) then
      dvdp = dvdp*Rgas*t/p - v/p
    endif
    if (present(dvdx)) then
      dvdx = dvdx*Rgas*t/p + z*Rgas*t/p
    endif
  end subroutine specificVolume

  !----------------------------------------------------------------------
  !> Calculate single-phase molar density given composition, temperature and
  !> pressure
  !>
  !> \author VGJ, 2024-10-04
  !----------------------------------------------------------------------
  subroutine molardensity(t,p,x,phase,rho,drdt,drdp,drdx)
    implicit none
    ! Transferred variables
    integer, intent(in) :: phase !< Phase identifyer
    real, intent(in) :: t !< K - Temperature
    real, intent(in) :: p !< Pa - Pressure
    real, dimension(1:nc), intent(in) :: x !< Compozition
    real, intent(out) :: rho !< m3/mol - Specific volume
    real, optional, intent(out) :: drdt !< m3/mol/K - Specific volume differential wrpt. temperature
    real, optional, intent(out) :: drdp !< m3/mol/Pa - Specific volume differential wrpt. pressure
    real, optional, dimension(1:nc), intent(out) :: drdx !< m3/mol - Specific volume differential wrpt. mole numbers
    ! Locals
    real :: v, dvdt, dvdp
    real, dimension(1:nc) :: dvdx
    call specificVolume(t, p, x, phase, v, dvdt, dvdp, dvdx)
    rho = 1. / v
    if (present(drdt)) then
      drdt = - (1. / v**2) * dvdt
    endif
    if (present(drdp)) then
      drdp = - (1. / v**2) * dvdp
    endif
    if (present(drdx)) then
      drdx = - (1. / v**2) * dvdx
    endif
  end subroutine molardensity

  !----------------------------------------------------------------------
  !> Calculate gas-liquid or single-phase specific volume given composition,
  !> temperature and pressure
  !>
  !> \author MH, 2012-07-30
  !----------------------------------------------------------------------
  function twoPhaseSpecificVolume(t,p,z,x,y,beta,phase,betaL) result(v)
    implicit none
    ! Transferred variables
    integer, intent(in) :: phase !< Phase identifyer
    real, intent(in) :: t !< K - Temperature
    real, intent(in) :: p !< Pa - Pressure
    real, intent(in) :: beta !< Gas phase mole fraction
    real, dimension(1:nc), intent(in) :: x !< Liquid compozition
    real, dimension(1:nc), intent(in) :: y !< Gas compozition
    real, dimension(1:nc), intent(in) :: z !< Overall compozition
    real :: v !< m3/mol - Specific mixture volume
    real, optional, intent(in) :: betaL !< Liquid phase mole fraction
    ! Locals
    real :: vg, vl
    integer :: sphase
    !--------------------------------------------------------------------
    if (phase == TWOPH) then
      call specificVolume(t,p,x,LIQPH,vl)
      call specificVolume(t,p,y,VAPPH,vg)
      if (present(betaL)) then
        v = beta*vg+betaL*vl
      else
        v = beta*vg+(1-beta)*vl
      endif
    else
      sphase = phase
      if (phase == SINGLEPH) then ! Only one solution of EoS
        sphase = LIQPH
      endif
      call specificVolume(t,p,z,sphase,v)
    endif
  end function twoPhaseSpecificVolume

  !----------------------------------------------------------------------
  !> Calculate single-phase specific enthalpy given composition, temperature
  !> and pressure
  !>
  !> \author MH, 2012-03-20
  !----------------------------------------------------------------------
  subroutine enthalpy(t,p,x,phase,h,dhdt,dhdp,dhdx,residual)
    use single_phase, only: TP_CalcEnthalpy
    implicit none
    ! Transferred variables
    integer, intent(in) :: phase !< Phase identifyer
    real, intent(in) :: t !< K - Temperature
    real, intent(in) :: p !< Pa - Pressure
    real, dimension(1:nc), intent(in) :: x !< Compozition
    real, intent(out) :: h !< J/mol - Specific enthalpy
    real, optional, intent(out) :: dhdt !< J/mol/K - Specific enthalpy differential wrpt. temperature
    real, optional, intent(out) :: dhdp !< J/mol/Pa - Specific enthalpy differential wrpt. pressure
    real, optional, dimension(1:nc), intent(out) :: dhdx !< J/mol - Specific enthalpy differential wrpt. mole numbers
    logical, optional, intent(in) :: residual !< Set to true if only residual entropy is required
    ! Locals
    real, dimension(1:nc) :: xx
    integer :: ph
    logical :: res
    type(thermo_model), pointer :: act_mod_ptr
    class(base_eos_param), pointer :: act_eos_ptr
    !
    !--------------------------------------------------------------------
    res = .false.
    if (present(residual)) then
      res = residual
    endif
    xx = x(1:nc)/sum(x(1:nc))
    act_mod_ptr => get_active_thermo_model()
    ph = phase
    if (ph == SINGLEPH) then
      ph = LIQPH
    endif
    act_eos_ptr => get_active_eos()
    h = TP_CalcEnthalpy(nc,act_mod_ptr%comps,act_eos_ptr,&
         t,p,xx,ph,res,dhdt,dhdp,dhdx)
  end subroutine enthalpy

  !----------------------------------------------------------------------
  !> Calculate gas-liquid or single-phase specific enthalpy given composition,
  !> temperature and pressure
  !>
  !> \author MH, 2012-03-20
  !----------------------------------------------------------------------
  function twoPhaseEnthalpy(t,p,z,x,y,beta,phase,betaL) result(h)
    implicit none
    ! Transferred variables
    integer, intent(in) :: phase !< Phase identifyer
    real, intent(in) :: t !< K - Temperature
    real, intent(in) :: p !< Pa - Pressure
    real, intent(in) :: beta !< Gas phase mole fraction
    real, dimension(1:nc), intent(in) :: x !< Liquid compozition
    real, dimension(1:nc), intent(in) :: y !< Gas compozition
    real, dimension(1:nc), intent(in) :: z !< Overall compozition
    real, optional, intent(in) :: betaL !< Liquid phase mole fraction
    real :: h !< J/mol - Specific mixture enthalpy
    ! Locals
    real :: hg, hl
    !--------------------------------------------------------------------
    if (phase == TWOPH) then
      call enthalpy(t,p,y,VAPPH,hg)
      call enthalpy(t,p,x,LIQPH,hl)
      if (present(betaL)) then
        h = beta*hg+betaL*hl
      else
        h = beta*hg+(1.0-beta)*hl
      endif
    else
      if (phase == VAPPH) then
        call enthalpy(t,p,z,VAPPH,h)
      else
        call enthalpy(t,p,z,LIQPH,h)
      endif
    endif

  end function twoPhaseEnthalpy

  !----------------------------------------------------------------------
  !> Calculate single-phase specific entropy given composition, temperature
  !> and pressure
  !>
  !> \author MH, 2012-03-20
  !----------------------------------------------------------------------
  subroutine entropy(t,p,x,phase,s,dsdt,dsdp,dsdx,residual)
    use single_phase, only: TP_CalcEntropy
    implicit none
    ! Transferred variables
    integer, intent(in) :: phase !< Phase identifyer
    real, intent(in) :: t !< K - Temperature
    real, intent(in) :: p !< Pa - Pressure
    real, dimension(1:nc), intent(in) :: x !< Compozition
    real, intent(out) :: s !< J/mol/K - Specific entropy
    real, optional, intent(out) :: dsdt !< J/mol/K/K - Specific entropy differential wrpt. temperature
    real, optional, intent(out) :: dsdp !< J/mol/K/Pa - Specific entropy differential wrpt. pressure
    real, optional, dimension(1:nc), intent(out) :: dsdx !< J/mol/K - Specific entropy differential wrpt. mole numbers
    logical, optional, intent(in) :: residual !< Set to true if only residual entropy is required
    ! Locals
    real, dimension(1:nc) :: xx
    integer :: ph
    logical :: res
    type(thermo_model), pointer :: act_mod_ptr
    class(base_eos_param), pointer :: act_eos_ptr
    !
    !--------------------------------------------------------------------
    res = .false.
    if (present(residual)) then
      res = residual
    endif
    xx = x(1:nc)/sum(x(1:nc))
    act_mod_ptr => get_active_thermo_model()
    ph = phase
    if (ph == SINGLEPH) then
      ph = LIQPH
    endif

    act_eos_ptr => get_active_eos()
    s = TP_CalcEntropy(nc,act_mod_ptr%comps,act_eos_ptr,&
         t,p,xx,ph,res,dsdt,dsdp,dsdx)
  end subroutine entropy

  !----------------------------------------------------------------------
  !> Calculate gas-liquid or single-phase specific entropy given composition,
  !> temperature and pressure
  !>
  !> \author MH, 2012-03-20
  !----------------------------------------------------------------------
  function twoPhaseEntropy(t,p,z,x,y,beta,phase,betaL) result(s)
    implicit none
    ! Transferred variables
    integer, intent(in) :: phase !< Phase identifyer
    real, intent(in) :: t !< K - Temperature
    real, intent(in) :: p !< Pa - Pressure
    real, intent(in) :: beta !< Gas phase mole fraction
    real, dimension(1:nc), intent(in) :: x !< Liquid compozition
    real, dimension(1:nc), intent(in) :: y !< Gas compozition
    real, dimension(1:nc), intent(in) :: z !< Overall compozition
    real, optional, intent(in) :: betaL !< Liquid phase mole fraction
    real :: s !< J/mol/K - Specific mixture entropy
    ! Locals
    real :: sg, sl
    !
    !--------------------------------------------------------------------
    if (phase == TWOPH) then
      call entropy(t,p,y,VAPPH,sg)
      call entropy(t,p,x,LIQPH,sl)
      if (present(betaL)) then
        s = beta*sg+betaL*sl
      else
        s = beta*sg+(1.0-beta)*sl
      endif
    else
      if (phase == VAPPH) then
        call entropy(t,p,z,VAPPH,s)
      else
        call entropy(t,p,z,LIQPH,s)
      endif
    endif
  end function twoPhaseEntropy

  !----------------------------------------------------------------------
  !> Calculate gas-liquid or single-phase internal energy given composition,
  !> temperature, pressure and a phase state given by phase/beta.
  !>
  !> \author EA, 2014-09
  !----------------------------------------------------------------------
  function twoPhaseInternalEnergy(t,p,z,x,y,beta,phase,betaL) result(u)
    use eosTV, only: internal_energy_tv
    implicit none
    ! Input:
    real, intent(in)                  :: t !< K - Temperature
    real, intent(in)                  :: p !< Pa - Pressure
    real, dimension(1:nc), intent(in) :: z !< Overall compozition
    real, dimension(1:nc), intent(in) :: x !< Liquid compozition
    real, dimension(1:nc), intent(in) :: y !< Gas compozition
    real, intent(in)                  :: beta !< Gas phase mole fraction
    integer, intent(in)               :: phase !< Phase identifier
    real, optional, intent(in)        :: betaL !< Liquid phase mole fraction
    ! Output:
    real                              :: u !< J/mol - Specific internal energy
    ! Internal:
    real :: vg, ug, vl, ul, v
    integer :: sphase
    !--------------------------------------------------------------------
    if (phase == TWOPH) then
      ! Liquid phase
      call specificVolume(t,p,x,LIQPH,vl)
      call internal_energy_tv(t,vl,x,ul)
      ! Gas phase
      call specificVolume(t,p,y,VAPPH,vg)
      call internal_energy_tv(t,vg,y,ug)
      ! Combined
      if (present(betaL)) then
        u = beta*ug+betaL*ul
      else
        u = beta*ug+(1-beta)*ul
      endif
    else
      sphase = phase
      if (phase == SINGLEPH) then ! Only one solution of EoS
        sphase = LIQPH
      endif
      call specificVolume(t,p,z,sphase,v)
      call internal_energy_tv(t,v,z,u)
    endif
  end function twoPhaseInternalEnergy


  !----------------------------------------------------------------------
  !> Calculate pseudo critical point.
  !>
  !> \author MH, 2012-03-15
  !----------------------------------------------------------------------
  subroutine pseudo(x,tpc,ppc,acfpc,zpc,vpc)
    use single_phase, only: TP_CalcPseudo
    use cubic_eos, only: cb_eos
    implicit none
    ! Transferred variables
    real, dimension(1:nc), intent(in) :: x !< Compozition
    real, intent(out) :: tpc !< K - Pseudo critical temperature
    real, intent(out) :: vpc !< m3/mol - Pseudo critical specific volume
    real, intent(out) :: ppc !< Pa - Pseudo critical pressure
    real, intent(out) :: zpc !< - - Pseudo critical compressibillity
    ! Locals
    real, dimension(1:nc) :: xx
    real :: acfpc
    type(thermo_model), pointer :: act_mod_ptr
    class(base_eos_param), pointer :: act_eos_ptr
    !--------------------------------------------------------------------
    xx = x(1:nc)/sum(x(1:nc))
    act_mod_ptr => get_active_thermo_model()
    ! Note! SRK is used for LK
    act_eos_ptr => get_active_eos()
    select type(p_eos => act_eos_ptr)
    class is (cb_eos)
      call TP_CalcPseudo(nc,act_mod_ptr%comps,p_eos,xx,tpc,ppc,zpc,vpc)
    class default
      call stoperror("pseudo error")
    end select

    vpc = vpc * 1.0e-3 ! m3/kmol -> m3/mol
  end subroutine pseudo

  !----------------------------------------------------------------------
  !> Calculate pseudo critical point, or use estimate from
  !> alternative EoS if necessary.
  !>
  !> \author EA, 2015-01
  !----------------------------------------------------------------------
  subroutine pseudo_safe(x,tpc,ppc,zpc,vpc)
    use thermopack_var, only: nc, get_active_alt_eos
    use single_phase, only: TP_CalcPseudo
    use cubic_eos, only: cb_eos
    implicit none
    ! Input:
    real, dimension(1:nc), intent(in) :: x !< Compozition
    ! Output:
    real, intent(out) :: tpc !< K - Pseudo critical temperature
    real, intent(out) :: vpc !< m3/mol - Pseudo critical specific volume
    real, intent(out) :: ppc !< Pa - Pseudo critical pressure
    real, intent(out) :: zpc !< - - Pseudo critical compressibillity
    ! Locals
    real              :: acfpc
    type(thermo_model), pointer :: act_mod_ptr
    class(base_eos_param), pointer :: act_eos_ptr

    act_mod_ptr => get_active_thermo_model()

    if (act_mod_ptr%need_alternative_eos) then
       act_eos_ptr => get_active_alt_eos()
      select type(p_eos => act_eos_ptr)
      class is (cb_eos)
         call TP_CalcPseudo(nc,act_mod_ptr%comps,p_eos,x,tpc,ppc,zpc,vpc)
      class default
        call stoperror("pseudo_safe error")
      end select
      vpc = vpc * 1.0e-3 ! m3/kmol -> m3/mol
    else
      call pseudo(x,tpc,ppc,acfpc,zpc,vpc)
    endif

  end subroutine pseudo_safe

  !----------------------------------------------------------------------
  !> Get critical state (and more) of pure fluid
  !!
  !! \author MH, 2013-03-06
  !----------------------------------------------------------------------
  subroutine getCriticalParam(i,tci,pci,oi,vci,tnbi)
    use eosdata
    implicit none
    integer, intent(in) :: i !< Component index
    real, intent(out) :: tci !< K - Critical temperature
    real, intent(out) :: pci !< Pa - Critical pressure
    real, intent(out) :: oi  !< Acentric factor
    real, intent(out), optional :: vci  !< m3/mol - Critical volume
    real, intent(out), optional :: tnbi !< Normal boiling point  (gs)
    ! Locals
    type(thermo_model), pointer :: act_mod_ptr
    act_mod_ptr => get_active_thermo_model()
    ! Locals
    tci = act_mod_ptr%comps(i)%p_comp%tc
    pci = act_mod_ptr%comps(i)%p_comp%pc
    oi = act_mod_ptr%comps(i)%p_comp%acf
    if (present(tnbi)) then
      tnbi = act_mod_ptr%comps(i)%p_comp%tb
    endif
    if (present(vci)) then
      vci = (act_mod_ptr%comps(i)%p_comp%zc)*Rgas*tci/pci
    end if

  end subroutine getCriticalParam

  !----------------------------------------------------------------------
  !> Calculate single component ideal Gibbs energy.
  !> Unit: J/mol
  !>
  !> \author MH, 2013-03-06
  !----------------------------------------------------------------------
  subroutine ideal_gibbs_single(t,p,j,g,dgdt,dgdp)
    use ideal, only: Hideal_apparent, TP_Sideal_apparent
    use eos_parameters, only: single_eos
    implicit none
    ! Transferred variables
    real, intent(in) :: t                   !< K - Temperature
    real, intent(in) :: p                   !< Pa - Pressure
    integer, intent(in) :: j                !< Component index
    real, intent(out) :: g                  !< J/mol - Ideal Gibbs energy
    real, optional, intent(out) :: dgdt     !< J/mol/K - Temperature differential of ideal Gibbs energy
    real, optional, intent(out) :: dgdp     !< J/mol/Pa - Pressure differential of ideal Gibbs energy
    ! Locals
    real :: s, h, z(nc), g_T
    type(thermo_model), pointer :: act_mod_ptr
    class(base_eos_param), pointer :: act_eos_ptr
    logical :: calculated
    !--------------------------------------------------------------------
    !
    s = 0.0
    h = 0.0
    z = 0.0
    z(j) = 1.0
    act_mod_ptr => get_active_thermo_model()
    calculated = .false.
    act_eos_ptr => get_active_eos()
    ! Thermopack
    select type(eos => act_eos_ptr)
    class is (single_eos)
      if (allocated(eos%nist)) then
        calculated = .true.
        call eos%nist(j)%meos%calc_ideal_gibbs(t,P,g,g_T)
        s = -g_T
      endif
    end select
    if (.not. calculated) then
      h = Hideal_apparent(act_mod_ptr%comps,j,T)
      call TP_Sideal_apparent(act_mod_ptr%comps, j, T, P, s)
      g = h - T*s
    endif
    if (present(dgdt)) then
      dgdt = -s
    end if
    if (present(dgdp)) then
      dgdp=T*Rgas/P
    end if
  end subroutine ideal_gibbs_single

  !----------------------------------------------------------------------
  !> Calculate single component ideal entropy.
  !> Unit: J/mol/K
  !>
  !> \author MH, 2014-01
  !----------------------------------------------------------------------
  subroutine ideal_entropy_single(t,p,j,s,dsdt,dsdp)
    use ideal, only: TP_Sideal_apparent
    use eos_parameters, only: single_eos
    implicit none
    ! Transferred variables
    real, intent(in) :: t                   !< K - Temperature
    real, intent(in) :: p                   !< Pa - Pressure
    integer, intent(in) :: j                !< Component index
    real, intent(out) :: s                  !< J/mol/K - Ideal entropy
    real, optional, intent(out) :: dsdt     !< J/mol/K^2 - Temperature differential of ideal entropy
    real, optional, intent(out) :: dsdp     !< J/mol/Pa - Pressure differential of ideal entopy
    ! Locals
    real :: z(nc)
    type(thermo_model), pointer :: act_mod_ptr
    class(base_eos_param), pointer :: act_eos_ptr
    logical :: calculated
    !--------------------------------------------------------------------
    !
    z = 0.0
    z(j) = 1.0
    s = 0.0
    calculated = .false.
    act_eos_ptr => get_active_eos()
    select type(eos => act_eos_ptr)
    class is(single_eos)
      if (allocated(eos%nist)) then
        calculated = .true.
        call eos%nist(j)%meos%calc_ideal_entropy(t,P,s,dsdt)
      endif
    end select
    if (.not. calculated) then
      act_mod_ptr => get_active_thermo_model()
      call TP_Sideal_apparent(act_mod_ptr%comps, j, T, P, s, dsdt)
    endif
    if (present(dsdp)) then
      dsdp=-Rgas/P
    end if
  end subroutine ideal_entropy_single

  !----------------------------------------------------------------------
  !> Calculate single component ideal enthalpy.
  !> Unit: J/mol
  !>
  !> \author MH, 2014-01
  !----------------------------------------------------------------------
  subroutine ideal_enthalpy_single(t,j,h,dhdt)
    use ideal, only: Hideal_apparent, Cpideal_apparent
    use eos_parameters, only: single_eos
    implicit none
    ! Transferred variables
    real, intent(in) :: t                   !< K - Temperature
    integer, intent(in) :: j                !< Component index
    real, intent(out) :: h                  !< J/mol - Ideal enthalpy
    real, optional, intent(out) :: dhdt     !< J/mol/K - Temperature differential of ideal enthalpy
    ! Locals
    type(thermo_model), pointer :: act_mod_ptr
    class(base_eos_param), pointer :: act_eos_ptr
    logical :: calculated
    !--------------------------------------------------------------------
    !
    calculated = .false.
    act_eos_ptr => get_active_eos()
    select type(eos => act_eos_ptr)
    class is(single_eos)
      if (allocated(eos%nist)) then
        calculated = .true.
        call eos%nist(j)%meos%calc_ideal_enthalpy(t,h,dhdt)
      endif
    end select
    if (.not. calculated) then
      act_mod_ptr => get_active_thermo_model()
      h = Hideal_apparent(act_mod_ptr%comps,j,T)
      if (present(dhdt)) then
        dhdt = CPideal_apparent(act_mod_ptr%comps, j, T) ! J/mol/K
      end if
    endif
  end subroutine ideal_enthalpy_single

  !----------------------------------------------------------------------
  !> Calculate residual Gibbs energy.
  !> Unit: J/mol
  !>
  !> \author MH, 2013-10-17
  !----------------------------------------------------------------------
  subroutine residualGibbs(t,p,z,phase,gr,dgrdt,dgrdp,dgrdn,metaExtremum)
    use single_phase, only: TP_CalcGibbs
    implicit none
    ! Transferred variables
    real, intent(in) :: t                    !< K - Temperature
    real, intent(in) :: p                    !< Pa - Pressure
    real, dimension(nc), intent(in) :: z     !< Component fractions
    integer, intent(in) :: phase             !< Phase identifyer
    real, intent(out) :: gr                  !< J/mol - Residual Gibbs energy
    real, optional, intent(out) :: dgrdt     !< J/mol/K - Temperature differential of ideal Gibbs energy
    real, optional, intent(out) :: dgrdp     !< J/mol/Pa - Pressure differential of ideal Gibbs energy
    real, dimension(nc), optional, intent(out) :: dgrdn     !< J/mol^2 - Mole number differential of ideal Gibbs energy
    logical, optional, intent(in) :: metaExtremum !< Calculate phase properties at metastable extremum
    ! Locals
    integer :: gflag
    real, dimension(nc) :: xx
    type(thermo_model), pointer :: act_mod_ptr
    class(base_eos_param), pointer :: act_eos_ptr
    !--------------------------------------------------------------------
    !
    xx = z(1:nc)/sum(z(1:nc))
    act_mod_ptr => get_active_thermo_model()
    act_eos_ptr => get_active_eos()
    gflag = 1
    if (present(metaExtremum)) then
      if (metaExtremum) then
        gflag = 2
      endif
    endif
    call TP_CalcGibbs(nc,act_mod_ptr%comps,act_eos_ptr,&
         T,P,xx,phase,.true.,gr,dgrdt,dgrdp,dgrdn,gflag)
  end subroutine residualGibbs

  !----------------------------------------------------------------------
  !> Get mole weight.
  !> Unit: g/mol
  !>
  !> \author MH, 2013-03-06
  !----------------------------------------------------------------------
  function moleWeight(z) result(mw)
    use single_phase, only: TP_CalcMw
    implicit none
    ! Transferred variables
    real, dimension(1:nc), intent(in) :: z !< Composition
    real :: mw !< g/mol - Mole weight
    ! Locals
    type(thermo_model), pointer :: act_mod_ptr
    ! External
    !--------------------------------------------------------------------
    !
    act_mod_ptr => get_active_thermo_model()
    mw = TP_CalcMw(nc,act_mod_ptr%comps,z)
  end function moleWeight

  !----------------------------------------------------------------------
  !> Get component mole weight.
  !> Unit: g/mol
  !>
  !> \author MH, 2013-03-06
  !----------------------------------------------------------------------
  function compMoleWeight(j) result(mw)
    implicit none
    ! Transferred variables
    integer, intent(in) :: j !< Component index
    real :: mw !< g/mol - Mole weight
    ! Locals
    type(thermo_model), pointer :: act_mod_ptr
    !--------------------------------------------------------------------
    !
    act_mod_ptr => get_active_thermo_model()
    mw = act_mod_ptr%comps(j)%p_comp%mw
  end function compMoleWeight

  !----------------------------------------------------------------------
  !> Get estimation of pure component saturation pressure
  !> Unit: Pa
  !>
  !> \author MH, 2013-10-10
  !----------------------------------------------------------------------
  function PsatEstPure(j,T) result(psat)
    use ideal, only: EstPsat
    implicit none
    ! Transferred variables
    integer, intent(in) :: j !< Component index
    real, intent(in) :: T !< K - Temperature
    real :: psat !< Pa - Estimated saturation pressure
    type(thermo_model), pointer :: act_mod_ptr
    !--------------------------------------------------------------------
    !
    psat = 0.0
    act_mod_ptr => get_active_thermo_model()
    psat = EstPsat(act_mod_ptr%comps,j,T)
  end function PsatEstPure

end module eos
