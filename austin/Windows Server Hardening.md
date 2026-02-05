***
## Useful links
***
* Hardening Kitty (use with caution)
	* https://github.com/scipag/HardeningKitty
* Window Hardening Scripts (use with caution)
	* https://github.com/atlantsecurity/windows-hardening-scripts
* LGPO
	* https://download.microsoft.com/download/8/5/C/85C25433-A1B0-4FFA-9429-7E023E7DA8D8/LGPO.zip
* STIGViewer
	* https://dl.dod.cyber.mil/wp-content/uploads/stigs/zip/U_STIGViewer-win32_x64-3-4-0_msi.zip
* STIG GPO Package
	* https://dl.dod.cyber.mil/wp-content/uploads/stigs/zip/U_STIG_GPO_Package_October_2024.zip
* STIG SCAP Benchmarks
	* https://dl.dod.cyber.mil/wp-content/uploads/stigs/zip/U_MS_Windows_Server_2019_V3R3_STIG_SCAP_1-3_Benchmark.zip
	* https://dl.dod.cyber.mil/wp-content/uploads/stigs/zip/U_MS_Windows_Defender_Firewall_V2R3_STIG_SCAP_1-2_Benchmark.zip
	* https://dl.dod.cyber.mil/wp-content/uploads/stigs/zip/U_MS_Defender_Antivirus_V2R5_STIG_SCAP_1-2_Benchmark.zip
* SCAP Compliance Checker
	* https://dl.dod.cyber.mil/wp-content/uploads/stigs/zip/scc-5.10.1_Windows_bundle.zip
* STIG Library
	* https://dl.dod.cyber.mil/wp-content/uploads/stigs/zip/U_SRG-STIG_Library_January_2025.zip
* Sysinternals
	* https://download.sysinternals.com/files/SysinternalsSuite.zip
* 
### Updates
***
* The machine is set to download but not install updates
* Install updates
### DOD STIG & SCAP
***

1. Install SCC
2. Install STIGViewer
3. Launch SCC (SCAP Compliance Checker)
4. Install Benchmarks (Anti-Virus, Firewall, Server 2019 Benchmark)
5. Launch STIG Viewer
6. Click add STIG to library and add STIGs
7. Add the STIGs from step 4
8. Go back to SCC
9. Start the Scan
10. Once scan is complete click view results
11. Click on a result in the lower left panel
12. Right click a report on the right > show in directory
13. Copy path to results
14. Open STIG Viewer
15. Click open checklist on top right
16. Click create new checklist
17. Click import > results
18. Paste path
19. Open XML folder
20. Import all XCCDF files
21. Click fill checklist
22. Open a command prompt as admin
23. Cd into the LGPO folder
24. run `LGPO.exe /g "..\U_STIG_GPO_Package_October_2024\DOD WinSvr 2019 MS and DC v3r2\GPOs"`
25. run `LGPO.exe /g "..\U_STIG_GPO_Package_October_2024\DoD Windows Defender Firewall v2r2\GPOs"`
26. run `LGPO.exe /g "..\U_STIG_GPO_Package_October_2024\DoD Microsoft Defender Antivirus STIG v2r4\GPOs`
27. run gpupdate

### Local Security Policy
***
* Define: Machine account lockout threshold
* Enable: Do not allow anonymous enumeration of SAM accounts and shares
* Enable: Only elevate executables that are signed and validated
* Delete SlimJet from downloads