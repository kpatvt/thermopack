"""Module for defining files defining symbols to export from thermopack"""
from datetime import datetime
import sys
from shutil import move
from pathlib import Path


def get_export_statement(platform, compiler, export_info):
    export_statement = ""

    if export_info["module"] is None:
        if platform == MACOS:
            export_statement += "_"

        export_statement += export_info["method"]

        if not export_info["isBindC"]:
            export_statement += "_"
    else:
        if compiler == GNU:
            export_statement = "__" + export_info["module"] \
                + "_MOD_" + export_info["method"]
        elif compiler == IFORT:
            export_statement = export_info["module"] + "_mp_" \
                + export_info["method"] + "_"
        elif compiler == PGF90:
            export_statement = export_info["module"] + "_" \
                + export_info["method"] + "_"
        elif compiler == GENERIC:
            export_statement = "*" + export_info["method"] + "*"

    return export_statement


def get_export_header(linker):
    now = datetime.today().isoformat()
    if linker == LD_MSVC:
        comment_symbol = ";"
    else:
        comment_symbol = "#"
    header = comment_symbol + " File generated by thermopack/addon/pyUtils/exports/export_list.py\n"
    header += comment_symbol + " Time stamp: " + now
    if linker == LD_GCC:
        header += "\nlibthermopack {\n# Explicit list of symbols to be exported\n  global:"
    elif linker == LD_CLANG:
        header += "\n# Explicit list of symbols to be exported"
    elif linker == LD_MSVC:
        header += "\n; @NAME@.def : Declares the module parameters.\n\nLIBRARY\n\nEXPORTS"
    return header


def get_export_footer(linker):
    footer = None
    if linker == LD_GCC:
        footer = "\n  local: *;      # hide everything else\n};"
    return footer


def write_def_file(compiler, linker, platform, filename):
    lines = []
    header = get_export_header(linker)
    lines.append(header)
    for export in exports:
        export_statement = get_export_statement(platform, compiler, export)
        if linker == LD_GCC:
            lines.append("\t" + export_statement + ";")
        elif linker in (LD_CLANG, LD_MSVC):
            lines.append("\t" + export_statement)
    footer = get_export_footer(linker)
    if footer is not None:
        lines.append(footer)

    with open(filename, "w", encoding="utf-8") as f:
        for line in lines:
            f.write(line)
            f.write("\n")


def append_export(method, module=None, isBindC=False):
    """Append export symbol"""
    exports.append({'method': method, 'module': module, 'isBindC': isBindC})


exports = []

append_export("thermopack_init_c", isBindC=True)
append_export("thermopack_pressure_c", isBindC=True)
append_export("thermopack_specific_volume_c", isBindC=True)
append_export("thermopack_tpflash_c", isBindC=True)
append_export("thermopack_uvflash_c", isBindC=True)
append_export("thermopack_hpflash_c", isBindC=True)
append_export("thermopack_spflash_c", isBindC=True)
append_export("thermopack_bubt_c", isBindC=True)
append_export("thermopack_bubp_c", isBindC=True)
append_export("thermopack_dewt_c", isBindC=True)
append_export("thermopack_dewp_c", isBindC=True)
append_export("thermopack_zfac_c", isBindC=True)
append_export("thermopack_enthalpy_c", isBindC=True)
append_export("thermopack_entropy_c", isBindC=True)
append_export("thermopack_wilsonk_c", isBindC=True)
append_export("thermopack_wilsonki_c", isBindC=True)
append_export("thermopack_getcriticalparam_c", isBindC=True)
append_export("thermopack_moleweight_c", isBindC=True)
append_export("thermopack_compmoleweight_c", isBindC=True)
append_export("thermopack_puresat_t_c", isBindC=True)
append_export("thermopack_entropy_tv_c", isBindC=True)
append_export("thermopack_twophase_dhdt_c", isBindC=True)
append_export("thermopack_guess_phase_c", isBindC=True)
append_export("thermopack_thermo_c", isBindC=True)
append_export("get_phase_flags_c", isBindC=True)

append_export("thermopack_getkij")
append_export("thermopack_setkijandji")
append_export("thermopack_getlij")
append_export("thermopack_setlijandji")
append_export("thermopack_gethvparam")
append_export("thermopack_sethvparam")
append_export("thermopack_getwsparam")
append_export("thermopack_setwsparam")
append_export("thermopack_get_volume_shift_parameters")
append_export("thermopack_set_volume_shift_parameters")

append_export("thermopack_set_alpha_corr")
append_export("thermopack_set_beta_corr")

append_export("get_bp_term", "binaryplot")
append_export("vllebinaryxy", "binaryplot")
append_export("global_binary_plot", "binaryplot")
append_export("threephaseline", "binaryplot")

append_export("comp_index_active", "compdata")
append_export("comp_name_active", "compdata")
append_export("get_ideal_cp_correlation", "compdata")
append_export("set_ideal_cp_correlation", "compdata")

append_export("calccriticaltv", "critical")

append_export("get_energy_constants", "cubic_eos")
append_export("get_covolumes", "cubic_eos")

append_export("specificvolume", "eos")
append_export("zfac", "eos")
append_export("thermo", "eos")
append_export("entropy", "eos")
append_export("enthalpy", "eos")
append_export("compmoleweight", "eos")
append_export("getcriticalparam", "eos")
append_export("ideal_enthalpy_single", "eos")
append_export("ideal_entropy_single", "eos")

append_export("init_thermo", "eoslibinit")
append_export("init_cubic", "eoslibinit")
append_export("init_cubic_pseudo", "eoslibinit")
append_export("init_cpa", "eoslibinit")
append_export("init_pcsaft", "eoslibinit")
append_export("init_saftvrmie", "eoslibinit")
append_export("init_quantum_cubic", "eoslibinit")
append_export("init_tcpr", "eoslibinit")
append_export("init_quantum_saftvrmie", "eoslibinit")
append_export("init_extcsp", "eoslibinit")
append_export("init_lee_kesler", "eoslibinit")
append_export("init_multiparameter", "eoslibinit")
append_export("init_pets", "eoslibinit")
append_export("init_volume_translation", "eoslibinit")
append_export("redefine_critical_parameters", "eoslibinit")
append_export("init_lj", "eoslibinit")
append_export("init_ljs", "eoslibinit")

append_export("internal_energy_tv", "eostv")
append_export("entropy_tv", "eostv")
append_export("pressure", "eostv")
append_export("thermo_tv", "eostv")
append_export("enthalpy_tv", "eostv")
append_export("free_energy_tv", "eostv")
append_export("chemical_potential_tv", "eostv")
append_export("virial_coefficients", "eostv")
append_export("secondvirialcoeffmatrix", "eostv")
append_export("binarythirdvirialcoeffmatrix", "eostv")
append_export("entropy_tvp", "eostv")
append_export("thermo_tvp", "eostv")
append_export("enthalpy_tvp", "eostv")

append_export("fmt_energy_density", "fundamental_measure_theory")

append_export("calc_bmcsl_gij_fmt", "hardsphere_bmcsl")

append_export("set_entropy_reference_value", "ideal")
append_export("get_entropy_reference_value", "ideal")
append_export("set_enthalpy_reference_value", "ideal")
append_export("get_enthalpy_reference_value", "ideal")

append_export("isobar", "isolines")
append_export("isotherm", "isolines")
append_export("isenthalp", "isolines")
append_export("isentrope", "isolines")

append_export("map_jt_inversion", "joule_thompson_inversion")

append_export("ljs_bh_model_control", "lj_splined")
append_export("ljs_bh_get_pure_params", "lj_splined")
append_export("ljs_bh_set_pure_params", "lj_splined")
append_export("calc_ai_reduced_ljs_ex", "lj_splined")
append_export("ljs_bh_get_bh_diameter_div_sigma", "lj_splined")
append_export("calc_ljs_wca_ai_tr", "lj_splined")
append_export("ljs_uv_model_control", "lj_splined")
append_export("ljs_wca_model_control", "lj_splined")
append_export("ljs_wca_set_pure_params", "lj_splined")
append_export("ljs_wca_get_pure_params", "lj_splined")

append_export("solve_mu_t", "mut_solver")
append_export("solve_lnf_t", "mut_solver")
append_export("map_meta_isotherm", "mut_solver")

append_export("fres_multipol", "multipol")
append_export("multipol_model_control", "multipol")

append_export("lng_ii_pc_saft_tvn", "pc_saft_nonassoc")

append_export("setphtolerance", "ph_solver")
append_export("twophasephflash", "ph_solver")

append_export("twophasepsflash", "ps_solver")

append_export("get_saftvrmie_eps_kij", "saftvrmie_containers")
append_export("set_saftvrmie_eps_kij", "saftvrmie_containers")
append_export("get_saftvrmie_sigma_lij", "saftvrmie_containers")
append_export("set_saftvrmie_sigma_lij", "saftvrmie_containers")
append_export("get_saftvrmie_lr_gammaij", "saftvrmie_containers")
append_export("set_saftvrmie_lr_gammaij", "saftvrmie_containers")
append_export("get_saftvrmie_pure_fluid_param", "saftvrmie_containers")
append_export("set_saftvrmie_pure_fluid_param", "saftvrmie_containers")
append_export("get_feynman_hibbs_order", "saftvrmie_containers")
append_export("set_saftvrmie_mass", "saftvrmie_containers")

append_export("model_control_hs", "saftvrmie_interface")
append_export("model_control_a1", "saftvrmie_interface")
append_export("model_control_a2", "saftvrmie_interface")
append_export("model_control_a3", "saftvrmie_interface")
append_export("model_control_chain", "saftvrmie_interface")
append_export("hard_sphere_reference", "saftvrmie_interface")
append_export("set_temperature_cache_flag", "saftvrmie_interface")
append_export("calc_saftvrmie_term", "saftvrmie_interface")

append_export("print_cpa_report", "saft_interface")
append_export("cpa_get_kij", "saft_interface")
append_export("cpa_set_kij", "saft_interface")
append_export("cpa_set_pure_params", "saft_interface")
append_export("cpa_get_pure_params", "saft_interface")
append_export("cpa_set_kij", "saft_interface")
append_export("pc_saft_get_kij", "saft_interface")
append_export("pc_saft_set_kij_asym", "saft_interface")
append_export("calc_saft_dispersion", "saft_interface")
append_export("calc_hard_sphere_diameter", "saft_interface")
append_export("calc_hard_sphere_diameter_ij", "saft_interface")
append_export("pc_saft_get_pure_params", "saft_interface")
append_export("pc_saft_set_pure_params", "saft_interface")
append_export("de_broglie_wavelength", "saft_interface")
append_export("potential", "saft_interface")
append_export("adjust_mass_to_specified_de_boer_parameter", "saft_interface")
append_export("de_boer_parameter", "saft_interface")
append_export("calc_soft_repulsion", "saft_interface")
append_export("pets_get_pure_params", "saft_interface")
append_export("pets_set_pure_params", "saft_interface")
append_export("truncation_corrections", "saft_interface")
append_export("calc_saft_hard_sphere", "saft_interface")
append_export("test_fmt_compatibility", "saft_interface")
append_export("setcpaformulation", "saft_interface")
append_export("calc_assoc_phi", "saft_interface")
append_export("calc_saft_dispersion", "saft_interface")
append_export("calc_hard_sphere_diameter", "saft_interface")
append_export("pc_saft_get_pure_params", "saft_interface")
append_export("pc_saft_set_pure_params", "saft_interface")
append_export("de_broglie_wavelength", "saft_interface")
append_export("sigma_ij", "saft_interface")
append_export("epsilon_ij", "saft_interface")
append_export("sigma_eff_ij", "saft_interface")
append_export("epsilon_eff_ij", "saft_interface")
append_export("alpha", "saft_interface")
append_export("getactiveassocparams", "saft_interface")
append_export("setactiveassocparams", "saft_interface")

append_export("map_stability_limit", "spinodal")
append_export("initial_stab_limit_point", "spinodal")
append_export("map_meta_isentrope", "spinodal")
append_export("tv_meta_ps", "spinodal")

append_export("safe_bubt", "saturation")
append_export("safe_bubp", "saturation")
append_export("safe_dewt", "saturation")
append_export("safe_dewp", "saturation")

append_export("envelopeplot", "saturation_curve")
append_export("envelope_isentrope_cross", "saturation_curve")
append_export("pure_fluid_saturation_wrapper", "saturation_curve")

append_export("solid_init", "solideos")
append_export("solid_specificvolume", "solideos")
append_export("solid_enthalpy", "solideos")
append_export("solid_entropy", "solideos")

append_export("solidenvelopeplot", "solid_saturation")
append_export("melting_pressure_correlation", "solid_saturation")
append_export("sublimation_pressure_correlation", "solid_saturation")

append_export("sound_velocity_2ph", "speed_of_sound")
append_export("speed_of_sound_tv", "speed_of_sound")

append_export("guessphase", "thermo_utils")

append_export("set_numerical_robustness_level", "thermopack_var")
append_export("get_numerical_robustness_level", "thermopack_var")
append_export("get_rgas", "thermopack_var")
append_export("set_tmin", "thermopack_var")
append_export("get_tmin", "thermopack_var")
append_export("set_tmax", "thermopack_var")
append_export("get_tmax", "thermopack_var")
append_export("set_pmin", "thermopack_var")
append_export("get_pmin", "thermopack_var")
append_export("set_pmax", "thermopack_var")
append_export("get_pmax", "thermopack_var")
append_export("set_pmin", "thermopack_var")
append_export("get_pmin", "thermopack_var")
append_export("add_eos", "thermopack_var")
append_export("delete_eos", "thermopack_var")
append_export("activate_model", "thermopack_var")
append_export("get_eos_identification", "thermopack_var")

append_export("twophasetpflash", "tp_solver")

append_export("twophasesvflash", "sv_solver")

append_export("twophaseuvflash", "uv_solver")

# FORTRAN compilers
GNU = 1
IFORT = 2
PGF90 = 3
GENERIC = 4

# Linkers
LD_GCC = 1
LD_CLANG = 2
LD_MSVC = 3

# Platforms
LINUX = 1
MACOS = 2
WINDOWS = 3

if __name__ == "__main__":
    # Write export files
    write_def_file(GENERIC, LD_GCC, LINUX, "libthermopack_export.version")
    write_def_file(GENERIC, LD_CLANG, MACOS, "libthermopack_export.symbols")
    write_def_file(IFORT, LD_MSVC, WINDOWS, "thermopack.def")
    thermopackroot = Path(__file__).parents[3]
    move('libthermopack_export.version', thermopackroot/'libthermopack_export.version')
    move('libthermopack_export.symbols', thermopackroot/'libthermopack_export.symbols')
    move('thermopack.def', thermopackroot/'MSVStudio/thermopack.def')
