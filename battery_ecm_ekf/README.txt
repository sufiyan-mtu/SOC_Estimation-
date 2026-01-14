Battery ECM + EKF — Quick Start (Notepad)
====================================================

WHAT TO DO (basic flow)
-----------------------
1) Open the Simulink model:  mdl/ECM_EKF_WLTP_kalman.mdl
   - On load, the model’s PostLoadFcn auto-runs three scripts:
     • scripts/setup_ecm.m        (writes OCV & ECM lookup tables to mdl/ecm_dd.sldd)
     • scripts/setup_ekf.m        (upserts EKF tuning params & precomputed OCV slope)
     • scripts/Measured_data_import.m  (loads measured data: I_A, V_meas, Ts_data)

2) Click Run in Simulink.
   - When the simulation stops, the StopFcn auto-runs the validators (plots + save to results/):
     • scripts/make_ecm_report.m
     • scripts/make_ekf_report.m

WHERE THINGS ARE
----------------
• Model:            mdl/ECM_EKF_WLTP_kalman.mdl
• Data dictionary:  mdl/ecm_dd.sldd
• Scripts folder:   scripts/
   - setup_ecm.m
   - setup_ekf.m
   - Measured_data_import.m
   - make_ecm_report.m
   - make_ekf_report.m
• Data files:       data/   (WLTP/HPPC MAT files, lookup tables)
• Results:          results/   (PNG + PDF figures saved by the report scripts)


TO USE A DIFFERENT MEASURED DATA FILE
-------------------------------------
Edit the filename on the dataFile line inside scripts/Measured_data_import.m, for example:

   dataFile   = fullfile(repoRoot, 'data', '10-25-19_11.29 960_WLTP206b.mat');

Save the script, then either reload the model or run Measured_data_import again, and re-run the simulation.



RESULTS SAVED BY VALIDATORS
---------------------------
The end-of-simulation report scripts save figures to results/ with timestamped names:
   • ECM: ecm_fig1_YYYYMMDD_HHMMSS.png / .pdf
          ecm_fig2_YYYYMMDD_HHMMSS.png / .pdf
   • EKF: ekf_fig1_YYYYMMDD_HHMMSS.png / .pdf
          ekf_fig2_YYYYMMDD_HHMMSS.png / .pdf
   • ECM: Final_Report (Has the development process and results tabulated)

RETUNE THE EKF (important)
--------------------------
1) Open scripts/setup_ekf.m and adjust parameters (typical knobs):
   - Q_proc     (SoC process variance, per step)
   - R_meas     (voltage measurement variance, V^2)
   - H_min      (Jacobian slope floor)
   - SlopeMethod  ('gradient' or 'pchip' for OCV slope)
   - soc_min / soc_max (SoC clamps)
2) In MATLAB, run:  setup_ekf
   - This upserts new values into mdl/ecm_dd.sldd.
3) Run the simulation again and check EKF validation figures.

SIGNALS EXPECTED IN out.logsout
-------------------------------
ECM:  V_meas, V_ter, I_A, SOC_cc, OCV_cc, (optional: R0, R1, R2, C1, C2, Vrc1, Vrc2, Vr0)
EKF:  SOC_kalman, V_error, (optional: Innov), K_out, P_out


That’s it — open the model, run, and review the ECM & EKF figures.
