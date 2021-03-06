### A Pluto.jl notebook ###
# v0.18.0

using Markdown
using InteractiveUtils

# This Pluto notebook uses @bind for interactivity. When running this notebook outside of Pluto, the following 'mock version' of @bind gives bound variables a default value (instead of an error).
macro bind(def, element)
    quote
        local iv = try Base.loaded_modules[Base.PkgId(Base.UUID("6e696c72-6542-2067-7265-42206c756150"), "AbstractPlutoDingetjes")].Bonds.initial_value catch; b -> missing; end
        local el = $(esc(element))
        global $(esc(def)) = Core.applicable(Base.get, el) ? Base.get(el) : iv(el)
        el
    end
end

# ╔═╡ 59062c8d-edbf-4966-a786-724f9438618c
begin
	using Plots
	using Printf
	using Unitful
	using DataFrames
	using CSV
	using Images
	using Interpolations
	using QuadGK
	using UnitfulEquivalences
	using Markdown
	using InteractiveUtils
	using PlutoUI
	using LsqFit
	using Distributions
	using Statistics
	using StatsBase
	using LaTeXStrings
end

# ╔═╡ 547c0f35-243e-4038-bb66-65b627bda4b0
begin
	using Peaks
	using Glob
	using FFTW
	using DSP
end

# ╔═╡ 9d66c472-b742-49b3-9495-1c3be998108b
import Unitful:
    nm, μm, mm, cm, m, km,
    mg, g, kg,
    ps, ns, μs, ms, s, minute, hr, d, yr, Hz, kHz, MHz, GHz,
    eV,
    μJ, mJ, J,
	μW, mW, W,
    A, N, mol, mmol, V, L, M

# ╔═╡ c3b89fa7-67f8-4cc3-b3ba-fcb304f44669
import PhysicalConstants.CODATA2018: N_A

# ╔═╡ bd9eed27-fc29-41ff-bf12-ec0cd3881ea2
function ingredients(path::String)
	# this is from the Julia source code (evalfile in base/loading.jl)
	# but with the modification that it returns the module instead of the last object
	name = Symbol(basename(path))
	m = Module(name)
	Core.eval(m,
        Expr(:toplevel,
             :(eval(x) = $(Expr(:core, :eval))($name, x)),
             :(include(x) = $(Expr(:top, :include))($name, x)),
             :(include(mapexpr::Function, x) = $(Expr(:top, :include))(mapexpr, $name, x)),
             :(include($path))))
	m
end

# ╔═╡ ca6f7233-a1d1-403d-9416-835a51d360db
lfi = ingredients("../src/LaserLab.jl")

# ╔═╡ ac5daa7a-b00b-4975-906d-f68e455c2b53
begin
	spG = lfi.LaserLab.CsvG(';',',')  # spanish: decimals represented with ',' delimited with ';'
	enG = lfi.LaserLab.CsvG(',','.')  # english
	enG2 = lfi.LaserLab.CsvG('\t','.')  # english
	println("")
end

# ╔═╡ a8ffd5c7-2a6f-4955-8e9f-ea605a8cb24d
function fit_straight_line(tdata, vdata; pa0=[0.0, 0.5], i0=1)
	tfun(t, a, b) = a + b * t
	pfun(t, p) = p[1] .+ p[2] .* t
	il = length(tdata)
	fit = curve_fit(pfun, tdata[i0:il], vdata[i0:il], pa0)
	coef(fit), stderror(fit), tfun.(tdata, coef(fit)...)
end

# ╔═╡ ea4b37e5-fc26-4ca3-8788-20dd4c57536c
function fit_abs(absdf, absdict,i)
	xc = [absdict[name] for name in names(absdf[i, 2:end-1])]
	yc = collect(values(absdf[i, 2:end-1]))
	cfit, stderr, fft = fit_straight_line(xc, yc)
	absdf[i,1], xc, yc, cfit, stderr, fft  
end

# ╔═╡ c91bef90-362d-4bc7-8378-2f6dc55a20eb
iλ(λ, λ0) = λ - λ0 + 1

# ╔═╡ 96ae3a10-b116-4544-b282-59b1f58417bf
PlutoUI.TableOfContents(title="Measuring RuSL", indent=true)

# ╔═╡ 34b3d66e-3b39-43dc-922b-9ba6c15c1bac
md"""# The RuSL and IrSL molecules

RuSL and IsSL molecules are a type of phosphorescente molecules which can be used to calibrate the TOPATU laser setup.

The molecules emit ligh peaked in the red (green), with a lifetime in the range of 500-800 ns.
"""

# ╔═╡ 5927e85d-f206-4d51-9b0c-6d2d70a0a0da
load("../notebooks/img/rusl.png") 

# ╔═╡ 98bfd4d0-9257-4c2e-8256-29833c4b2850
md"""
# RuSL: Measurement of the absorption cross section 

To measure the absorption cross section for a molecular species (in particular RuSl) absorption data is taken with a fluorimeter for different wavelengths and at different concentrations. For each wavelength, a linear fit determines the molar absorption. 

The procedure is ilustrated below.

First, a DF with the info of absorption as a function of λ for different concentrations is loaded.
"""

# ╔═╡ cc7e6e63-7630-4500-a18b-92d254089a12
begin
	ruslAbs = lfi.LaserLab.load_df_from_csv("/Users/jj/JuliaProjects/LaserLab/data/RuSl", "BOLD_063_Rusilatrane_MeOH_calibration_curve.csv", spG)
	ruslAbs[!, :W] = convert.(Float64, ruslAbs[:, :W])
	sort!(ruslAbs, rev = false)
	first(ruslAbs,5)
end

# ╔═╡ 38f06b03-50b7-4254-b111-d9b15a39a910
md"""
Plotting the absorption at any given concentration as a function of λ gives similar results. The molecule has a strong absorption peak at 250nm, and a second peak near 450 nm. 
"""

# ╔═╡ b992f24e-ead5-4117-8744-1a81c16f13a7
begin
	prusl_5E_5M = plot(ruslAbs.W, ruslAbs.rusl_5E_5M, label="RuSL: 5e-5M", lw=2)
	prusl_1E_5M = plot!(ruslAbs.W, ruslAbs.rusl_1E_5M, label="RuSL: 2e-5M", lw=2)
	xlabel!("λ (nm) ")
	ylabel!("Abs (M)")
	#title!("Tranmission of the objective ")
end

# ╔═╡ a5bc9651-176f-41ed-8cc9-81c1accfc4db
md"""
To measure the absorption cross section at 250 nm, we represent the values of the absortivity as a function of the concentration for this wavelength, and fit a straight line. 
"""

# ╔═╡ 977a2703-17c9-443f-a110-334e38377909
ruslAbs[1, :]

# ╔═╡ 26decc7c-a3c2-41a3-8eec-5ed12296918f
ruslCon=Dict("rusl_5E_5M" =>5E-5,
			 "rusl_1E_5M" =>1E-5,
			 "rusl_5E_6M" =>5E-6,
			 "rusl_1E_6M" =>1E-6,
			 "rusl_5E_7M" =>5E-7,
		     "rusl_1E_7M" =>1E-7)

# ╔═╡ ac1d5662-e8c9-48a0-a30f-dcf9ca15af15
xc = [ruslCon[name] for name in names(ruslAbs[1, 2:end-1])]

# ╔═╡ ffa56bac-2f5c-4d1b-8e5a-7d3412393f14
yc = collect(values(ruslAbs[1, 2:end-1]))

# ╔═╡ fedadec6-70a7-483f-9199-877ef60a5861
cfit, stderr, fft = fit_straight_line(xc, yc)

# ╔═╡ dc1fd780-64d8-4113-b19f-9bb0733eed99
begin
	cal250 = scatter(xc, yc, markersize=3,
			color = :black,
		    legend=false,
			fmt = :png)
	plot(cal250, xc, fft)
	xlabel!("C (M)")
	ylabel!("Abs")
end

# ╔═╡ b01206a2-7b5e-4a7a-842b-354ab1ec5b0d
md"""
Fit at 250 nm. 

- Intercept at origin =$(round(cfit[1], sigdigits=5))
- Slope (molar absorption) = $(round(cfit[2], sigdigits=5)) ``M^{-1} cm^{-1}``
"""

# ╔═╡ fcbff47c-d7ee-471e-b452-2360a142ac29
md"""
The procedure needs to be repeated for all wavelengths. We start by defining a function that takes the dataframe, the dictionary defining the concentrations and an index that will later run through the wavelength colum, and return the wavelength value, fit parameters and function.

	fit_abs(absdf, absdict,i)
 
 `absdf : absorption dataframe`
 
 `absdict : dictionary defining the concentrations`
 
 `i : wavelength index`
"""

# ╔═╡ 9042910c-802b-4a71-8863-5b64984b3a8c
λ1, xc1, yc1, cfit1, stderr1, fft1 = fit_abs(ruslAbs, ruslCon, 1)

# ╔═╡ d8c646d9-6c1a-4ca1-8f4a-a22bb1623132
md"""
We can reproduce now the previous result, with:

- Intercept at origin =$(round(cfit1[1], sigdigits=5))
- Slope (molar absorption) = $(round(cfit1[2], sigdigits=5)) ``M^{-1} cm^{-1}``
- 
"""

# ╔═╡ c42f8de4-5790-4558-8e98-a16540c78885
begin
	sc1 = scatter(xc1, yc1, markersize=3,
			color = :black,
		    legend=false,
			fmt = :png)
	plot(sc1, xc1, fft1)
	xlabel!("C (M)")
	ylabel!("Abs")
end

# ╔═╡ bd2b9f50-672d-4cf2-806e-93c8b7d71918
md"""
We can now examine any wavelenght, by performing the fit at the chosen wavelength
"""

# ╔═╡ 73c8585e-6d3c-4119-a786-950244ceeeb2
nw = length(ruslAbs.W) 

# ╔═╡ 6a44f96c-a264-48b9-83f3-bc64a607c730
λ0 = Int(ruslAbs[1, 1])

# ╔═╡ b7715de1-59a9-460c-8c4e-535713f1e317
md""" select a wavelength to plot
"""

# ╔═╡ b80f21e4-331c-4677-84d4-77259c2422b4
@bind λ Slider(λ0:λ0+nw)

# ╔═╡ c4f1bc99-f0b2-45eb-afd5-19483de2e8c8
md"""
Wavelength selected = $λ nm

Wavelength index = $(iλ(λ, λ0)) 
"""

# ╔═╡ 725a2620-6e6d-4964-840a-ca318fe871db
λs, xcs, ycs, cfits, stderrs, ffts = fit_abs(ruslAbs, ruslCon, iλ(λ, λ0))

# ╔═╡ f866230f-0cbe-4462-a3d7-0ef148a944c9
begin
	scs = scatter(xcs, ycs, markersize=3,
			color = :black,
		    legend=false,
			fmt = :png)
	plot(scs, xcs, ffts)
	xlabel!("C (M)")
	ylabel!("Abs")
end

# ╔═╡ da025bce-a955-4f6a-916c-bac1e1f491dd
md"""
Fit result:

- Intercept at origin =$(round(cfits[1], sigdigits=5))
- Slope (molar absorption) = $(round(cfits[2], sigdigits=5)) ``M^{-1} cm^{-1}``
- 
"""

# ╔═╡ e6e50f4a-6da4-4b10-9b92-2c7436f57072
md"""
Finally we perform the fit for all the wavelengths
"""

# ╔═╡ 6056db12-a40c-4586-bb63-203fcd0c0cce
zeros(Float64, 10)

# ╔═╡ 9503331e-e97f-4ba9-84aa-c1e11c2f59d1
function fit_abs_all(absdf, absdict)
	nw = length(absdf.W) 
	W = zeros(Float64, nw)
	Abs = zeros(Float64, nw)
	for i in 1:nw
		λ, _, _, cfit, _, _ = fit_abs(absdf, absdict, i)
		W[i]   = λ
		Abs[i] = cfit[2]
	end
	W, Abs
end
	

# ╔═╡ f6d52515-c34a-4159-b4e7-625cba13763c
vλ, ϵ = fit_abs_all(ruslAbs, ruslCon)

# ╔═╡ 1e6c1d0b-8a3b-4cec-928f-a2e892fdbf5e
begin
	plot(vλ, ϵ, lw=2,
			color = :black,
		    legend=false,
			fmt = :png)
	xlabel!(L"\lambda ~(nm)")
	ylabel!(L"\epsilon ~ (M^{-1} cm^{-1})")
end

# ╔═╡ ea503006-18b6-47a1-8cb3-46d856dfe8b0
md"""
Finally, we can save the result in a dataframe
"""

# ╔═╡ 89f8c950-32bd-49d3-8a62-79e0040646ec
absorptionXSdf = DataFrame("λ" => vλ, "ϵ" => ϵ)

# ╔═╡ fa0c5865-1c22-4a9e-b393-b8f5875ff841
absorptionXSdfMeta = DataFrame("λ" => ["nm"], "ϵ" =>["M^-1cm^-1"])

# ╔═╡ 15ef23fa-1633-4954-a927-1d289d5573ec
md"""
And write to file
"""

# ╔═╡ d7c66368-4769-4d50-b20f-9ea4ed6eee5a
begin
	CSV.write("/Users/jj/JuliaProjects/LaserLab/data/RuSl/absXSdf.csv", absorptionXSdf)
	CSV.write("/Users/jj/JuliaProjects/LaserLab/data/RuSl/absXSmd.csv", absorptionXSdfMeta)
end

# ╔═╡ 2838b7e5-752b-4cb6-bec5-f48d122e859c
begin
	absorptionXSdf2 = lfi.LaserLab.load_df_from_csv("/Users/jj/JuliaProjects/LaserLab/data/RuSl", "absXSdf.csv", enG)
	first(absorptionXSdf2,5)
end

# ╔═╡ c4cb9e33-4362-40f9-baba-ac822cbedc64
begin
	absorptionXSdfMeta2 = lfi.LaserLab.load_df_from_csv("/Users/jj/JuliaProjects/LaserLab/data/RuSl", "absXSmd.csv", enG)
	first(absorptionXSdfMeta2,1)
end

# ╔═╡ 7e150a69-0070-4371-b5c0-02b7ad70d813
md"### Fluorescence cross section and quantum yield"

# ╔═╡ 16cdbadf-4deb-4a66-8ab7-84437a4fe3d4
load("../notebooks/img/RuSlAbs.png")

# ╔═╡ 9cc3dfcb-b95d-4086-a228-ed4753f6ca0d
begin
	ϵabs = 8801.5/(M*cm)
	Q    = 0.9
	λexc = 485.0nm
	λEM  = 690.0nm
	println("")
end

# ╔═╡ 4a0e30fe-398e-4d80-86a2-bfc384cbc6e6
md"
- The absorption cross section at 469 nm is ϵ = $ϵabs
- Measured quantum yield is Q= $Q
- The excitation wavelength of the laser is $λexc
"

# ╔═╡ 591f9fcb-7ad1-400e-af0a-29686a4914ec
md"### Emission spectrum on ML

- ML of RuSL, at a nominal packing of 1 molecule per nm
- Peak emission around $λEM
"

# ╔═╡ 9cc092e9-40d2-4c5a-9b55-4e2adccb3382
begin
	dfrusl = lfi.LaserLab.load_df_from_csv("/Users/jj/JuliaProjects/LaserLab/data/fluorimeter", "RuSL_quartz.csv", spG)
	dfrusl[!, :λ] = convert.(Float64, dfrusl[:, :λ]) 
	first(dfrusl,10)
	println("")
end

# ╔═╡ d75a8426-c97b-422e-8c69-3f3ce94c5370
begin
plot(dfrusl.λ, dfrusl.QUARTZ_Rusilatrane_A, lw=2, label="RuSL on quartz")
xlabel!("λ (nm)")
ylabel!("I (a.u.)")
end

# ╔═╡ a7d330cf-5093-490f-adc8-e482e3084806
md"## Temporal dependence of the phosoprescence"

# ╔═╡ 280a17c4-6d5e-4ff3-a5ab-dbbcb7199bb2
begin
	dfruslt = lfi.LaserLab.load_df_from_csv("/Users/jj/JuliaProjects/LaserLab/data/fluorimeter", "Ru_SL_time.csv", spG)
	dfruslt[!, :λ] = convert.(Float64, dfruslt[:, :λ]) 
	first(dfruslt,10)
	println("")
end

# ╔═╡ a230e061-b6ab-49d4-bdad-730d75e20e9c
md"### The data fits (but not too well) to a single exponential

- At large times the fluorimeter may be measuring a constant pedestal
  "

# ╔═╡ 6d5e295c-1c57-4a92-aee2-3ffcbb3306df
begin
	mexp(t, p) = p[1] * exp.(-t/p[2])
	pa0 = [3500.0, 500.0]
	tdata = dfruslt.λ
	ydata= dfruslt.Ru_Quartz
	fit = curve_fit(mexp, tdata, ydata, pa0)
	cofe = coef(fit)
	stder = stderror(fit)
	println("")
end

# ╔═╡ 80447dc7-1103-4019-bc64-283d4a9368a0
@info "fit coefficients" cofe

# ╔═╡ 08ec5b69-946f-407e-ac8d-bf8814cc0121
@info "coefficient errors (std)" stder

# ╔═╡ 58b227ac-627f-49ba-bc58-75039c65733b
md"## The RUSL experiment

The goal of the RUSL experiment is to use the (modified) TOPATU setup to measure the spectrum (color) and temporal response of the RuSL ML on quartz. This experiment has already been performed in the fluorimeter (see results below), and the main purpose of RUSL is to repeat it with the laser setup to calibrate the system (including temporal response)

The experiment ingredients are:

- A ML of RuSL on quartz. 
- A pulsed laser of 480 nm (EPL 480 from Edimburgh).
- The topatu setup, modified to allow measurement of spectrum (with filters) and time response. 
- The measurement must include spectral response (number of photons observed as a function of the wavelength) and time response (which requires time-stamps for the observed photons)
"

# ╔═╡ 4223f9f8-8ee6-4ea9-a7bc-6379c81c48c0
load("../notebooks/img/Nuevo_SET_UP_RuSl.png") 

# ╔═╡ fabba61a-f28d-4535-b0e3-e94f5098bb0a
md"## The Monolayers

A Monolayer (ML) of fluorophores is characterised by the packing of the fluorophores, the absorption cross section of the individual fluorophores and their emission spectra. These properties may also be correlated or can be modified when moving from solution to ML. For example colective effects of the interference with substrate can modify the naive assumption that the total fluorescence is the product of the number of fluorophores and the fluorescence per fluorophore. However, it is useful to start with the simplest assumption that all cross sections measured in solution hold in solid/gas interface

"

# ╔═╡ 7a1fcff4-6948-4333-b971-8fbf31c7d3ee
md"#### Define the fluorophores at nominal excitation ($λexc)"

# ╔═╡ a917927d-d471-4465-abd1-30d959af0b45
frusl = lfi.LaserLab.Fluorophore(λexc, λEM, ϵabs, Q)

# ╔═╡ aa4283d7-37d4-4aaf-a5b7-b515466e545d
begin
	λepl    = 485.0nm
	Pkepl   = 35.0mW
	P200khz = 0.6μW
	fepl    = 200.0kHz
	wepl    = 140.0ps
	dc      = uconvert(μs, 1.0/fepl)
end

# ╔═╡ 93b78d1a-ee07-4d66-b5a4-c7a109a24f81
md"## Laser
- The experiment requires a VUV pulsed laser. For the experiment we will use a repetition rate of $fepl (pulsed each 1 μs)
- 
- The nominal laser for the experiment is the EPL485
  
| λepl   | Pkepl      | fepl  | wepl | dc| P|
|:-------| ---------- |:-----:|:-----:|:-----:|:-----:|
| $λepl  | $Pkepl| $fepl | $wepl |$dc| $P200khz

"

# ╔═╡ 19b7d7fb-adab-4f29-82af-d059525921ee
md"#### Define laser"

# ╔═╡ 102a2054-2fd5-406e-8bb4-20ecb47c278f
epl485 = lfi.LaserLab.PulsedLaser(λepl, Pkepl, fepl, P200khz, wepl)

# ╔═╡ e97474ef-145f-45c8-96f6-213acf4a3b41
md"### Beam shape
- The beam has an oval shape, with a long axis of 3.5 mm and short axis of 1.5 mm
- The entrance iris diameter of the objective is 2.5 mm. The beam overfills one of the dimensions and not quite the other.
- We will make the approch that the beam fills the entrance iris
"

# ╔═╡ 106f7063-719e-4eff-857d-3566d6e6d4c8
load("../notebooks/img/beamspot.png") 

# ╔═╡ 177762d5-b9f2-449b-abba-256f3d4318ad
md"## Objective

The objective directs the laser light into the ML. For the first round of experiments, it is convenient to focus the laser to the smaller possible spot (diffraction limit). This is done by filling the entrance pupil of the objective with the laser. 

Let's assume a setup in which the back lens of the objective is filled up with a laser beam (assumed to be gaussian). The waist of the beam, assuming $z_r >> f$ (where $f$ is the focal distance of the objective and $z_r$ is the depth of focus of the gaussian beam) is then $w_0 = d/2$, where $d$ is the diameter of the back lens of the objective

The experiment must be conducted in a dry atmosphere, to avoid quenching the phosporescence. Thus the sample must be in a box at vacuum or filled with an inert gas (e.g, argon, N2). The objective may be inside the box (if working distance is small) or outside (if working distance is large)

We will use a reflection objective, the MM40XF-VUV, characterized by a large working distance and large (for an air coupled) NA. 
"

# ╔═╡ 4e4ab4e5-bacc-4c58-8000-10602a1f8465
#load("../notebooks/img/LMM40XVUV.png")  

# ╔═╡ e35f8650-dc2e-46f3-9220-26754e8860e0
#md"### Characteristics of the MM40xVUV

#| Feature   | Value     
#|:-------| ---------- |
#| Entrance pupil diameter  | $dd| 
#| Focal length  | $fl| 
#|NA  | $NA|
#|M (magnification)  | $MM|
#|working distance  | $wd|
#|Tranmission (250-1000 nm)  | $T|
#|Damage threshold  | $dth|
#"

# ╔═╡ 13827ddc-bebd-44d5-929f-f4ac6f43b093
#begin
#	dd    = 5.1mm
#	fl    = 5.0mm
#	NA    = 0.5
#	dth   = 0.3J/cm^2
#	wd    = 7.8mm
#	T     = 0.85
#	MM     = 40.0
#end

# ╔═╡ 2a07dd38-bac4-410c-8135-5c4e6f851df6
#lmm40xf_uvv  = lfi.LaserLab.Objective("LMM40XF-UVVV", fl, dd, MM)

# ╔═╡ ebe4e491-1c61-45cb-a559-64fa3f5fbb9d
load("../notebooks/img/NikonMUE31900.png") 

# ╔═╡ d6d6dc94-5b99-4de6-a5c3-ab2be2b49d32
begin
	dd    = 2.4mm
	fl    = 2.0mm
	NA    = 0.6
	wd    = 10.0mm
	MM    = 100.0
end

# ╔═╡ a3703591-17d4-4049-8c1b-21a4c8329ffd
md"### Characteristics of the NikonMUE31900

| Feature   | Value     
|:-------| ---------- |
| Entrance pupil diameter  | $dd| 
| Focal length  | $fl| 
|NA  | $NA|
|M (magnification)  | $MM|
|working distance  | $wd|
"

# ╔═╡ b0112287-c957-4ce3-ba24-9c47c8128b2d
tobj  = lfi.LaserLab.Objective("Nikon", fl, dd, MM)

# ╔═╡ 417fecfd-b316-4e63-8e68-303d4c568434
md"## The laser beam as a Gaussian Laser"

# ╔═╡ bbd09112-d6cd-4f0f-9a87-7b85be983e09
md"### Focusing the beam"

# ╔═╡ 8c405cc2-e8b5-4125-b21d-f7a22f94fb59
md"The beam is now focused in a narrow spot by the objective. "

# ╔═╡ ebe77978-7d7f-407d-9a73-4be3568265ef
gepl485 = lfi.LaserLab.propagate_paralell_beam(epl485, tobj)

# ╔═╡ e7e7b1ca-b27f-406c-9df0-5ffea702719f
md"### Spot size and Depth of focus

The spot size is $(round(lfi.LaserLab.spot_size(gepl485)/nm,digits=1)) nm, while the depth of focus is $(round(lfi.LaserLab.depth_of_focus(gepl485)/nm, digits=1)) nm. "

# ╔═╡ f48eb494-f9f5-4e4f-9fc0-ffa20312155a
i0mWcm2f = round(uconvert(W/cm^2, gepl485.I0)/(W*cm^-2), sigdigits=2);

# ╔═╡ fc5b2f60-2c04-4835-a222-9971189ac54e
ng0 = round(gepl485.γ0/(Hz*cm^-2), sigdigits=2);

# ╔═╡ 4eeabd93-cd82-4051-b2d0-bee3db1723e4
md"### Power density 

- The power density in the spot is now much larger: $(i0mWcm2f ) W/cm2
- Or in term of photon density: $(ng0) Hz/cm2
"

# ╔═╡ e40a68c6-5885-49d1-9259-fdd3be09fee4
md"In a gaussian laser, the intensity as a function of the radial direction ($\rho$) and the direction of propagation (z) is:

$I(\rho, z) = I_0 ( W_0 / W(z))^2 \exp{-2 \rho^2/W^2(z)}$
"

# ╔═╡ f79fb47b-b4f7-442a-927f-0c186e673b80
md"Since both the spot size and the depth of focus are small, we can approximate the intensity that will illuminate the molecules of the mono layer with I(0,0)"

# ╔═╡ 8da11b18-5934-4207-941b-795969173f21
fI = lfi.LaserLab.I(gepl485) ;

# ╔═╡ ce47be17-7773-4797-beb7-202d3c02555a
begin()
zl=-5.0:0.01:5.0
p1 = plot(zl, fI.(0.0*μm, zl*μm)/(mW * cm^-2), label="I(0,z)")
xlabel!("z (μm)")
ylabel!("I(0,z)")

rl=-1.0:0.01:1.0
p2 = plot(rl, fI.(rl*μm, 0*μm)/(mW * cm^-2), label="I(ρ,0)")
xlabel!("ρ (μm)")
ylabel!("I(0,z)")

plot(p1,p2, layout = (1, 2), legend=false, fmt = :png)
end

# ╔═╡ 498d145b-ce5f-46a5-b77e-31f412e04eb9
md"### Packing of the monolayer

- One can define the packing of the ML in terms of the 'pitch' or distance separating two molecules. This is a crucial parameter of the experiment.

"

# ╔═╡ 0d4a0651-4ce4-497e-8764-2bcbbef83cf1
md"##### molecular pitch (in nm)"

# ╔═╡ d437cc55-8c19-4d0b-86d8-760da3956895
@bind mp NumberField(1.0:10.0^3; default=1.0)

# ╔═╡ 7dedd16b-4279-4f50-8120-d9ef394f3e13
pitch = mp*nm;

# ╔═╡ 649fa1b3-0dd2-487d-9bdf-7db97a0ec178
ml = lfi.LaserLab.Monolayer(pitch);

# ╔═╡ 92a5b436-1d8e-4436-8dda-8b1d3518bdea
md"This corresponds to $(uconvert(cm^-2, ml.σ)) molecules"

# ╔═╡ 8d4516fd-8838-4e5f-a61d-9dc1f65b31ad
aspot = π * gepl485.w0^2;

# ╔═╡ c5b0405a-a991-45a5-aa04-d09020b0c7f0
md"### Spot area
- The area of the spot iluminated by the beam is $(round(uconvert(μm^2,aspot)/μm^2, digits=1)) μm2"

# ╔═╡ 03e15d19-ea63-413e-8ec5-4d50e28558ac
nmol = uconvert(μm^2, aspot) * ml.σ;

# ╔═╡ 4a1cf5fc-b44f-4b19-ac8e-d610da0a17cb
md"### Number of molecules in the spot
- The number of molecules in the spot illuminated by the beam is: $(round(nmol))"

# ╔═╡ 39a7f7b4-058b-4283-b35c-4409ea9e478a
md"### Fluorescence per molecule
- The fluorescence of each molecule is the product of the beam density, the fluorescence cross section and the quantum yield:

$f = I_0 \cdot \sigma \cdot Q$
"

# ╔═╡ abe34c91-9824-45e4-8865-7b3f73ff8758
fmrs = lfi.LaserLab.fluorescence(frusl, gepl485.γ0);

# ╔═╡ 52aeae45-0dfc-48f2-a362-20d1add0ff7f
md"### Fluorescence per molecule for free and chelated species
- The fluorescence per molecule for RuSL is: $(round(fmrs/Hz)) Hz, 
"

# ╔═╡ 9d97d16a-8f90-4ff7-ac0b-ee610c20ee32
sfrs = fmrs * nmol;

# ╔═╡ 960ba1ef-495d-4bb2-8aff-73cb68ae440e
md"### Total fluorescence in the spot

The total fluorescence in the spot is the product of the number of molecules and the fluorescence per molecule:

- Fluorescence in spot for RuSL = $(round(sfrs/Hz, sigdigits=1)) Hz

"

# ╔═╡ 8815a3e2-e559-4857-b20e-14aa5f91d341
md"## Filters and dichroics"

# ╔═╡ 89aa75b3-2263-450e-9f2e-cd7c875a7919
md"### Dichroic DMLP 567
- Transmits > 98% of the light above 600 nm.
"

# ╔═╡ b5045344-fb52-4b2e-88b9-1c1d4d1d50f6
begin
	dmlp567 = lfi.LaserLab.load_df_from_csv("/Users/jj/JuliaProjects/LaserLab/data/Filters", "dmlp567.csv", spG)
	dmlp567[!, :λ] = convert.(Float64, dmlp567[:, :λ]) 
	first(dmlp567,10)
	println("")
end

# ╔═╡ f6fefa8e-8490-4c0d-b707-c9a95011cbb1
begin
	dp1 = plot(dmlp567.λ, dmlp567.T, lw=2, label = "T", fmt = :png)
	plot(dp1, dmlp567.λ, dmlp567.R, lw=2, label = "R", fmt = :png)
	xlabel!("λ (nm)")
	ylabel!("T (R) (%)")
end

# ╔═╡ 3555a982-9879-460f-babf-6f31c11c6f7f
md"### High band pass filter FGL550"

# ╔═╡ 954d503d-19f2-4575-84d7-2d1722a28a7f
begin
	fgl550 = lfi.LaserLab.load_df_from_csv("/Users/jj/JuliaProjects/LaserLab/data/Filters", "fgl550.csv", spG)
	fgl550[!, :λ] = convert.(Float64, fgl550[:, :λ]) 
	first(fgl550,10)
	println("")
end

# ╔═╡ 41eb41f7-bc6e-4dce-8d39-68142fd329db
begin
	plot(fgl550.λ, fgl550.T, lw=2, label = "T", fmt = :png)
	xlabel!("λ (nm)")
	ylabel!("T  (%)")
end

# ╔═╡ bc6ba394-d1b8-4c1b-8a01-c23bcd29178c
md"### Color filters FF01"

# ╔═╡ 7140a27e-4cde-4c7d-a794-9a624e540677
begin
	ff550 = lfi.LaserLab.load_df_from_csv("/Users/jj/JuliaProjects/LaserLab/data/Filters", "FF01-550_49_Spectrum.csv", enG2)
	ff600 = lfi.LaserLab.load_df_from_csv("/Users/jj/JuliaProjects/LaserLab/data/Filters", "FF01-600_52-25.csv", enG2)
	ff650 = lfi.LaserLab.load_df_from_csv("/Users/jj/JuliaProjects/LaserLab/data/Filters", "FF01-650_54_Spectrum.csv", enG2)
	ff692 = lfi.LaserLab.load_df_from_csv("/Users/jj/JuliaProjects/LaserLab/data/Filters", "FF01-692_40_Spectrum.csv", enG2)
	ff732 = lfi.LaserLab.load_df_from_csv("/Users/jj/JuliaProjects/LaserLab/data/Filters", "FF01-732_68_Spectrum.csv", enG2)
	ff810 = lfi.LaserLab.load_df_from_csv("/Users/jj/JuliaProjects/LaserLab/data/Filters", "FF01-810_Spectrum.csv", spG)
	ff810[!, :T] = ff810[!, :T] * 0.01 
	first(ff550,10)
	println("")
end

# ╔═╡ b0bf01be-6a53-4c42-9d9a-752bf4652986
begin
	ff550s = filter(df -> df.T >= 0.01, ff550)
	ff600s = filter(df -> df.T >= 0.01, ff600)
	ff650s = filter(df -> df.T >= 0.01, ff650)
	ff692s = filter(df -> df.T >= 0.01, ff692)
	ff732s = filter(df -> df.T >= 0.01, ff732)
	ff810s = filter(df -> df.T >= 0.01, ff810)
	println("")
end

# ╔═╡ 0ee9bd36-7192-4922-abaf-7d7d08605915
begin
	p550 = plot(ff550s.λ, ff550s.T, lw=2, label = "FF01-550", fmt = :png)
	p600 = plot(p550, ff600s.λ, ff600s.T, lw=2, label = "FF01-600", fmt = :png)
	p650 = plot(p600, ff650s.λ, ff650s.T, lw=2, label = "FF01-650", fmt = :png)
	p692 = plot(p650, ff692s.λ, ff692s.T, lw=2, label = "FF01-692", fmt = :png)
	p732 = plot(p692, ff732s.λ, ff732s.T, lw=2, label = "FF01-732", fmt = :png)
	p810 = plot(p732, ff810s.λ, ff810s.T, lw=2, label = "FF01-810", fmt = :png)
	xlabel!("λ (nm)")
	ylabel!("T  ")
end

# ╔═╡ df1ff4c2-8c84-455a-9cc4-7fdc34e2cb83
begin
	λm = [550.0, 600.0, 650.0, 692.0, 732.0] * nm
	Im = [0.23, 0.43, 3.44, 1.7, 1.22] * MHz
	wm = [size(ff550s)[1], size(ff600s)[1], size(ff650s)[1], size(ff692s)[1], size(ff732s)[1]] * nm 
	Ilm = uconvert.(MHz*μm^-1, Im ./λm) 
	Ilmx = round.(Ilm ./ (MHz*μm^-1),  sigdigits=2)
	It = sum(Im)
end

# ╔═╡ d5ef9a03-f716-454b-a5de-0c67ee935679
md"## Summary of measurements with TOPATU setup and RuSL ML
- P = $(epl485.P)
- f = $(epl485.f) 
  
| λ filter (nm)   | FF550      | FF600  | FF650 | FF692| FF732|
|:-------| ---------- |:-----:|:-----:|:-----:|:-----:|
| λ0 (nm)  | $(λm[1])| $(λm[2]) | $(λm[3]) |$(λm[4])| $(λm[5])
| w (nm)  | $(wm[1])| $(wm[2]) | $(wm[3]) |$(wm[4])| $(wm[5])
| I (MHz)  | $(Im[1])| $(Im[2]) | $(Im[3]) |$(Im[4])| $(Im[5])
| Ilm (MHz/nm)  | $(Ilmx[1])| $(Ilmx[2]) | $(Ilmx[3]) |$(Ilmx[4])| $(Ilmx[5])

Total observed light = $It

"

# ╔═╡ 6396d4af-e668-4a73-b8be-b73b8b41267c
begin
ps2 = scatter(λm/nm, Ilmx, markersize=3,
		color = :black,
	    legend=false,
		fmt = :png)
plot(ps2, λm/nm, Ilmx, lw=2)
xlabel!("λ (nm)")
ylabel!("Il (MHz/μm)")
end

# ╔═╡ 6445e2c6-4dcc-44dd-bdda-564e4c9b3911
effCCD = lfi.LaserLab.ccd()

# ╔═╡ 7e0b0616-5dd0-44d3-beab-4fa32521d3ff
begin
	wl = 350.0:10.0:1000.0
	eccd = effCCD.(collect(wl))
	plot(wl, eccd, lw=2)
	xlabel!("λ (nm)")
	ylabel!("ϵ")
end

# ╔═╡ b49c15a7-d9de-4942-b09c-7f2ed9b4550e
function ccd_eff(lmn,wmn)
	effx = zeros(1,5)
	for i in 1:5
		effx[i] = (effCCD(lmn[i] - wmn[i]/2.0) + effCCD(lmn[i] + wmn[i]/2.0))/2.0
	end
	#@info "effx" effx
	sum(effx)/length(effx)
end

# ╔═╡ 356b7b35-6794-40d0-8c88-b8e066f086a6
begin
	lmn = λm/nm
	wmn = wm/nm
	ϵobj = 0.95
	ϵd = 0.95
	ϵf = 0.85
	ϵPMT = 0.1
	ϵNA      = lfi.LaserLab.transmission(tobj)
	efccd = ccd_eff(lmn,wmn)
	ϵT =  ϵobj^2 * ϵd^2 * ϵf * ϵPMT * ϵNA
	ϵTc =  ϵobj^2 * ϵd^2 * ϵf * efccd * ϵNA
	qf = 0.1
	println("")
end

# ╔═╡ f38318dd-f7bb-4bf1-9bc9-d1f7ed8a8397
md"## Detected Light

The detected light is the product of the emitted fluorescence and the detection efficiency, which in turns includes:

- Transmission efficiency of the objective : ϵ_obj_vuv =$(ϵobj^2)
- Tranmission due to the NA ϵ_NA = $(round(ϵNA, digits=2))
- Transmission due to the dichroic ϵd =$(ϵd^2)
- Tranmission due to the filters ϵf = $ϵf
- Transmission due to PMT ϵPMT = $ϵPMT
- Transmission due to CCD ϵCCD = $(round(efccd, digits=2))
- Quenching factor of phosphorescence due to oxygen = $qf
- The total tranmission (with PMT) is $(round(ϵT, digits=3))
- The total tranmission (with CCD) is $(round(ϵTc, digits=3))
"

# ╔═╡ f615fc39-bfd9-45ce-84fe-a28921bde525


# ╔═╡ 43e8a5f1-512c-46b7-91f6-89d3c7e81368
begin
	osf  = sfrs * ϵT * qf
	osfc = sfrs * ϵTc * qf
end

# ╔═╡ d49e7e9b-6487-407b-aef7-2884461879a0
md" ### Expected observed light in the PMT

Thus the total expected light in the PMT for a ML of ~ $(uconvert(cm^-2, ml.σ)) molecules is:

- Expected observed light:
  -  with PMT= $(round(osf/Hz, sigdigits=1)) Hz
  -  with CCD= $(round(osfc/Hz, sigdigits=1)) Hz

"

# ╔═╡ ae5f17d2-3c31-4a9c-85e4-f2f22625d86b
begin
	P0 = 1.5μW
	f0  = 500kHz
	println("")
end

# ╔═╡ c3952378-79bb-4605-8ffb-828c1e3e3321
#load("../notebooks/img/RuSlCCD250222.png")   

# ╔═╡ 0f7ff8a4-43e4-4829-a4b4-78594664cee2
md"## TCSP experiments"

# ╔═╡ 131f4e45-85f5-43bc-8c32-d59f8803bfd6
md"### Typical setup"

# ╔═╡ a4066207-4c50-4360-b43f-218d5355ff3e
load("../notebooks/img/tcsp_setup.png")   

# ╔═╡ 218fc76e-1060-40ff-a52f-d884441380e2
md"### Photon counting technique"

# ╔═╡ 58b61eac-e1de-48f3-a37b-ecc1f8d5f8ab
load("../notebooks/img/tcspc.png")  

# ╔═╡ 320f9c75-5047-4a4c-890b-ffdc70767634
md" The phothon counting technique requires that one photon is recorded on average per pulse (in this case in the period 1-5 mus). This is to avoid inefficiencies which can bias the measurement as ilustrated below."

# ╔═╡ b97cd0a9-ee46-4520-a408-f60150bbea74
load("../notebooks/img/tcspc_deadtime.png")  

# ╔═╡ b96961fd-6a9a-40bb-b582-2b3586f56edb
md"However, most TCSPC techniques are designed for short interval times. The dead time is typically a few nanoseconds, thus no loss for dead time is expected here. Nevertheless the system is designed to record just one photon per pulse. This implies that the average number of photons must be reduced to 1 per 1 (5) μs. This can be done by:
- attenuating the laser light
- reducing the laser power
- spacing the molecules in the ML
"

# ╔═╡ eba3554f-ae6f-4a3d-8131-43ffa2743977
md"# Appendix"

# ╔═╡ f57ca807-9b3a-4f77-9607-74ee3a411990
md"## Fitting"

# ╔═╡ 7a6a3b8a-8b1c-41d5-ab25-7d294f1bee3d
md"### *func1dfit* is a light wrapper to curve_fit"

# ╔═╡ 92698c05-edf3-4b9e-a10a-1da9ed0dc82a
"""
    func1dfit(ffit::Function, x::Vector{<:Real},
              y::Vector{<:Real}, p0::Vector{<:Real},
              lb::Vector{Float64}, ub::Vector{Float64})

Fit a function to the data x, y with start prediction p0
and return coefficients and errors.
"""
func1dfit(ffit::Function, x::Vector{<:Real},
          y::Vector{<:Real}, p0::Vector{<:Real},
          lb::Vector{<:Real}, ub::Vector{<:Real}) = curve_fit(ffit, x, y, p0, 
			                                                 lower=lb, upper=ub)
    

# ╔═╡ 0dd448d1-9952-438c-9284-e0c320c955aa
md"### Example: fit to a polynomial"

# ╔═╡ f8b61a8e-2679-48cd-842c-17d6e6ee760e

pol3(x, a, b, c, d) = a + b*x + c*x^2 + d*x^3


# ╔═╡ bfc6e346-3525-47d7-a436-ffa02dab11b9
begin
	err_sigma = 0.04
	x=collect(LinRange(0., 10., 100))
	p0 = [10.0, 1.0, 0.7, 0.5]
	y = pol3.(x, p0...)
    y += rand(Normal(0, err_sigma), length(y))
    lb = fill( 0.0, length(p0))
    ub = fill(20.0, length(p0))
    pol3_fit = @. pol(x, p) = p[1] + p[2] * x + p[3] * x^2 + p[4] * x^3
    fq = func1dfit(pol3_fit, x, y, p0, lb, ub)
	cfq = coef(fq)
	sfq = stderror(fq)
end

# ╔═╡ 2ff6f551-2662-43a5-9776-70951ff40364
@info "fit coefficients" cfq

# ╔═╡ ec3cd40c-6a52-48fd-a3ce-9e091250e981
yf = pol3.(x, cfq...);

# ╔═╡ 525b0316-8374-4882-aa5b-84f2bf33c5c3
@info "coefficient errors (std)" sfq

# ╔═╡ 840fa50e-bf0f-42f9-8e7f-ec3cc4bdb9af
sfq

# ╔═╡ 5738e27c-5307-4623-bd43-67f66b7b97d2
@info "margin_of_error (90%)" margin_error(fq, 0.1)

# ╔═╡ 14360d77-340e-488d-bed0-00f408ef1dd4
all(isapprox.(cfq, p0; atol=err_sigma))

# ╔═╡ 685fd840-64b1-427d-83f3-217664ea9798
begin
pp1 = scatter(x, y,
	          label="p3",
			  markersize=2,
			  color = :black,
	          legend=false,
		   	  fmt = :png)
pp2 = plot(pp1, x, yf, lw=2)
	
xlabel!("x")
ylabel!("p3(x)")
end

# ╔═╡ 8ecc8206-275b-4d55-9b01-e82e7f2df5dc
md"### Fit an exponential"

# ╔═╡ aac7a640-97fe-46c0-89b3-7e76978baf0d
exp(1.0)

# ╔═╡ 89ef5f08-7a1e-42a5-8fcf-b7efa63a8a68
expo(t, N, λ) = N*exp(-t/λ)

# ╔═╡ 426f8190-7865-4bd1-bc23-0adb5fc1892c
begin
	err_sigma2 = 0.05
	t=collect(LinRange(0.0, 5000.0, 1000))
	p0t = [3500.0, 500.0]
	yt = expo.(t, p0t...)
	yts = yt + rand(Normal(0, err_sigma2), length(yt)) .* yt
    lbt = [0.0, 0.0]
    ubt = [50000.0, 50000.0]
    expo_fit = @. expo(t, p) = p[1]*exp(-t/p[2])
    fqe = func1dfit(expo_fit, t, yts, p0t, lbt, ubt)
	cfqe = coef(fqe)
	sfqe = stderror(fqe)
end

# ╔═╡ 2fdad658-0b71-4d42-8591-9284fee3aeb6

begin
	tft = expo.(tdata, coef(fit)...);
	println("")
end

# ╔═╡ 5a0cc7d8-a3c3-45b9-8b91-9528e4938fb0
begin
ps1 = scatter(tdata, ydata, markersize=1,
		color = :black,
	    legend=false,
		fmt = :png)
pp = plot(ps1, tdata, tft, lw=2,fmt = :png)
xlabel!("t (ns)")
ylabel!("I (a.u.)")
end

# ╔═╡ f1e6c6b6-49fa-44bb-bb9a-07986f6a1d13
expo(0,3000.,500.)

# ╔═╡ c54205d5-ea1a-4416-b4b0-3bdb168dae61
fqe.converged

# ╔═╡ b83d4ff4-cc73-4cf7-abad-78da291eb404
@info "fit coefficients" cfqe

# ╔═╡ 13ad7221-0d2d-4a77-9258-9edace85fde0
@info "coefficient errors (std)" sfqe

# ╔═╡ f2b2cc4d-54ed-4f2f-80bc-bc3bf82bb2e8
begin
pp3 = scatter(t, yt,
	          label="expo",
			  markersize=2,
			  color = :black,
	          legend=false,
		   	  fmt = :png)
#pp2 = plot(pp1, x, yf, lw=2)
	
xlabel!("t")
ylabel!("expo(t)")
end

# ╔═╡ 00000000-0000-0000-0000-000000000001
PLUTO_PROJECT_TOML_CONTENTS = """
[deps]
CSV = "336ed68f-0bac-5ca0-87d4-7b16caf5d00b"
DSP = "717857b8-e6f2-59f4-9121-6e50c889abd2"
DataFrames = "a93c6f00-e57d-5684-b7b6-d8193f3e46c0"
Distributions = "31c24e10-a181-5473-b8eb-7969acd0382f"
FFTW = "7a1cc6ca-52ef-59f5-83cd-3a7055c09341"
Glob = "c27321d9-0574-5035-807b-f59d2c89b15c"
Images = "916415d5-f1e6-5110-898d-aaa5f9f070e0"
InteractiveUtils = "b77e0a4c-d291-57a0-90e8-8db25a27a240"
Interpolations = "a98d9a8b-a2ab-59e6-89dd-64a1c18fca59"
LaTeXStrings = "b964fa9f-0449-5b57-a5c2-d3ea65f4040f"
LsqFit = "2fda8390-95c7-5789-9bda-21331edee243"
Markdown = "d6f4376e-aef5-505a-96c1-9c027394607a"
Peaks = "18e31ff7-3703-566c-8e60-38913d67486b"
PhysicalConstants = "5ad8b20f-a522-5ce9-bfc9-ddf1d5bda6ab"
Plots = "91a5bcdd-55d7-5caf-9e0b-520d859cae80"
PlutoUI = "7f904dfe-b85e-4ff6-b463-dae2292396a8"
Printf = "de0858da-6303-5e67-8744-51eddeeeb8d7"
QuadGK = "1fd47b50-473d-5c70-9696-f719f8f3bcdc"
Statistics = "10745b16-79ce-11e8-11f9-7d13ad32a3b2"
StatsBase = "2913bbd2-ae8a-5f71-8c99-4fb6c76f3a91"
Unitful = "1986cc42-f94f-5a68-af5c-568840ba703d"
UnitfulEquivalences = "da9c4bc3-91c8-4f02-8a40-6b990d2a7e0c"

[compat]
CSV = "~0.10.4"
DSP = "~0.7.5"
DataFrames = "~1.3.2"
Distributions = "~0.25.53"
FFTW = "~1.4.6"
Glob = "~1.3.0"
Images = "~0.25.1"
Interpolations = "~0.13.5"
LaTeXStrings = "~1.3.0"
LsqFit = "~0.12.1"
Peaks = "~0.4.0"
PhysicalConstants = "~0.2.1"
Plots = "~1.27.4"
PlutoUI = "~0.7.38"
QuadGK = "~2.4.2"
StatsBase = "~0.33.16"
Unitful = "~1.11.0"
UnitfulEquivalences = "~0.2.0"
"""

# ╔═╡ 00000000-0000-0000-0000-000000000002
PLUTO_MANIFEST_TOML_CONTENTS = """
# This file is machine-generated - editing it directly is not advised

julia_version = "1.7.2"
manifest_format = "2.0"

[[deps.AbstractFFTs]]
deps = ["ChainRulesCore", "LinearAlgebra"]
git-tree-sha1 = "6f1d9bc1c08f9f4a8fa92e3ea3cb50153a1b40d4"
uuid = "621f4979-c628-5d54-868e-fcf4e3e8185c"
version = "1.1.0"

[[deps.AbstractPlutoDingetjes]]
deps = ["Pkg"]
git-tree-sha1 = "8eaf9f1b4921132a4cff3f36a1d9ba923b14a481"
uuid = "6e696c72-6542-2067-7265-42206c756150"
version = "1.1.4"

[[deps.Adapt]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "af92965fb30777147966f58acb05da51c5616b5f"
uuid = "79e6a3ab-5dfb-504d-930d-738a2a938a0e"
version = "3.3.3"

[[deps.ArgTools]]
uuid = "0dad84c5-d112-42e6-8d28-ef12dabb789f"

[[deps.ArnoldiMethod]]
deps = ["LinearAlgebra", "Random", "StaticArrays"]
git-tree-sha1 = "62e51b39331de8911e4a7ff6f5aaf38a5f4cc0ae"
uuid = "ec485272-7323-5ecc-a04f-4719b315124d"
version = "0.2.0"

[[deps.ArrayInterface]]
deps = ["Compat", "IfElse", "LinearAlgebra", "Requires", "SparseArrays", "Static"]
git-tree-sha1 = "8d4a07999261b4461daae67b2d1e12ae1a097741"
uuid = "4fba245c-0d91-5ea0-9b3e-6abc04ee57a9"
version = "5.0.6"

[[deps.Artifacts]]
uuid = "56f22d72-fd6d-98f1-02f0-08ddc0907c33"

[[deps.AxisAlgorithms]]
deps = ["LinearAlgebra", "Random", "SparseArrays", "WoodburyMatrices"]
git-tree-sha1 = "66771c8d21c8ff5e3a93379480a2307ac36863f7"
uuid = "13072b0f-2c55-5437-9ae7-d433b7a33950"
version = "1.0.1"

[[deps.AxisArrays]]
deps = ["Dates", "IntervalSets", "IterTools", "RangeArrays"]
git-tree-sha1 = "cf6875678085aed97f52bfc493baaebeb6d40bcb"
uuid = "39de3d68-74b9-583c-8d2d-e117c070f3a9"
version = "0.4.5"

[[deps.Base64]]
uuid = "2a0f44e3-6c83-55bd-87e4-b1978d98bd5f"

[[deps.Bzip2_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "19a35467a82e236ff51bc17a3a44b69ef35185a2"
uuid = "6e34b625-4abd-537c-b88f-471c36dfa7a0"
version = "1.0.8+0"

[[deps.CEnum]]
git-tree-sha1 = "215a9aa4a1f23fbd05b92769fdd62559488d70e9"
uuid = "fa961155-64e5-5f13-b03f-caf6b980ea82"
version = "0.4.1"

[[deps.CSV]]
deps = ["CodecZlib", "Dates", "FilePathsBase", "InlineStrings", "Mmap", "Parsers", "PooledArrays", "SentinelArrays", "Tables", "Unicode", "WeakRefStrings"]
git-tree-sha1 = "873fb188a4b9d76549b81465b1f75c82aaf59238"
uuid = "336ed68f-0bac-5ca0-87d4-7b16caf5d00b"
version = "0.10.4"

[[deps.Cairo_jll]]
deps = ["Artifacts", "Bzip2_jll", "Fontconfig_jll", "FreeType2_jll", "Glib_jll", "JLLWrappers", "LZO_jll", "Libdl", "Pixman_jll", "Pkg", "Xorg_libXext_jll", "Xorg_libXrender_jll", "Zlib_jll", "libpng_jll"]
git-tree-sha1 = "4b859a208b2397a7a623a03449e4636bdb17bcf2"
uuid = "83423d85-b0ee-5818-9007-b63ccbeb887a"
version = "1.16.1+1"

[[deps.Calculus]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "f641eb0a4f00c343bbc32346e1217b86f3ce9dad"
uuid = "49dc2e85-a5d0-5ad3-a950-438e2897f1b9"
version = "0.5.1"

[[deps.CatIndices]]
deps = ["CustomUnitRanges", "OffsetArrays"]
git-tree-sha1 = "a0f80a09780eed9b1d106a1bf62041c2efc995bc"
uuid = "aafaddc9-749c-510e-ac4f-586e18779b91"
version = "0.2.2"

[[deps.ChainRulesCore]]
deps = ["Compat", "LinearAlgebra", "SparseArrays"]
git-tree-sha1 = "9950387274246d08af38f6eef8cb5480862a435f"
uuid = "d360d2e6-b24c-11e9-a2a3-2a2ae2dbcce4"
version = "1.14.0"

[[deps.ChangesOfVariables]]
deps = ["ChainRulesCore", "LinearAlgebra", "Test"]
git-tree-sha1 = "bf98fa45a0a4cee295de98d4c1462be26345b9a1"
uuid = "9e997f8a-9a97-42d5-a9f1-ce6bfc15e2c0"
version = "0.1.2"

[[deps.Clustering]]
deps = ["Distances", "LinearAlgebra", "NearestNeighbors", "Printf", "SparseArrays", "Statistics", "StatsBase"]
git-tree-sha1 = "75479b7df4167267d75294d14b58244695beb2ac"
uuid = "aaaa29a8-35af-508c-8bc3-b662a17a0fe5"
version = "0.14.2"

[[deps.CodecZlib]]
deps = ["TranscodingStreams", "Zlib_jll"]
git-tree-sha1 = "ded953804d019afa9a3f98981d99b33e3db7b6da"
uuid = "944b1d66-785c-5afd-91f1-9de20f533193"
version = "0.7.0"

[[deps.ColorSchemes]]
deps = ["ColorTypes", "Colors", "FixedPointNumbers", "Random"]
git-tree-sha1 = "12fc73e5e0af68ad3137b886e3f7c1eacfca2640"
uuid = "35d6a980-a343-548e-a6ea-1d62b119f2f4"
version = "3.17.1"

[[deps.ColorTypes]]
deps = ["FixedPointNumbers", "Random"]
git-tree-sha1 = "024fe24d83e4a5bf5fc80501a314ce0d1aa35597"
uuid = "3da002f7-5984-5a60-b8a6-cbb66c0b333f"
version = "0.11.0"

[[deps.ColorVectorSpace]]
deps = ["ColorTypes", "FixedPointNumbers", "LinearAlgebra", "SpecialFunctions", "Statistics", "TensorCore"]
git-tree-sha1 = "3f1f500312161f1ae067abe07d13b40f78f32e07"
uuid = "c3611d14-8923-5661-9e6a-0046d554d3a4"
version = "0.9.8"

[[deps.Colors]]
deps = ["ColorTypes", "FixedPointNumbers", "Reexport"]
git-tree-sha1 = "417b0ed7b8b838aa6ca0a87aadf1bb9eb111ce40"
uuid = "5ae59095-9a9b-59fe-a467-6f913c188581"
version = "0.12.8"

[[deps.CommonSolve]]
git-tree-sha1 = "68a0743f578349ada8bc911a5cbd5a2ef6ed6d1f"
uuid = "38540f10-b2f7-11e9-35d8-d573e4eb0ff2"
version = "0.2.0"

[[deps.CommonSubexpressions]]
deps = ["MacroTools", "Test"]
git-tree-sha1 = "7b8a93dba8af7e3b42fecabf646260105ac373f7"
uuid = "bbf7d656-a473-5ed7-a52c-81e309532950"
version = "0.3.0"

[[deps.Compat]]
deps = ["Base64", "Dates", "DelimitedFiles", "Distributed", "InteractiveUtils", "LibGit2", "Libdl", "LinearAlgebra", "Markdown", "Mmap", "Pkg", "Printf", "REPL", "Random", "SHA", "Serialization", "SharedArrays", "Sockets", "SparseArrays", "Statistics", "Test", "UUIDs", "Unicode"]
git-tree-sha1 = "96b0bc6c52df76506efc8a441c6cf1adcb1babc4"
uuid = "34da2185-b29b-5c13-b0c7-acf172513d20"
version = "3.42.0"

[[deps.CompilerSupportLibraries_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "e66e0078-7015-5450-92f7-15fbd957f2ae"

[[deps.ComputationalResources]]
git-tree-sha1 = "52cb3ec90e8a8bea0e62e275ba577ad0f74821f7"
uuid = "ed09eef8-17a6-5b46-8889-db040fac31e3"
version = "0.3.2"

[[deps.ConstructionBase]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "f74e9d5388b8620b4cee35d4c5a618dd4dc547f4"
uuid = "187b0558-2788-49d3-abe0-74a17ed4e7c9"
version = "1.3.0"

[[deps.Contour]]
deps = ["StaticArrays"]
git-tree-sha1 = "9f02045d934dc030edad45944ea80dbd1f0ebea7"
uuid = "d38c429a-6771-53c6-b99e-75d170b6e991"
version = "0.5.7"

[[deps.CoordinateTransformations]]
deps = ["LinearAlgebra", "StaticArrays"]
git-tree-sha1 = "681ea870b918e7cff7111da58791d7f718067a19"
uuid = "150eb455-5306-5404-9cee-2592286d6298"
version = "0.6.2"

[[deps.Crayons]]
git-tree-sha1 = "249fe38abf76d48563e2f4556bebd215aa317e15"
uuid = "a8cc5b0e-0ffa-5ad4-8c14-923d3ee1735f"
version = "4.1.1"

[[deps.CustomUnitRanges]]
git-tree-sha1 = "1a3f97f907e6dd8983b744d2642651bb162a3f7a"
uuid = "dc8bdbbb-1ca9-579f-8c36-e416f6a65cce"
version = "1.0.2"

[[deps.DSP]]
deps = ["Compat", "FFTW", "IterTools", "LinearAlgebra", "Polynomials", "Random", "Reexport", "SpecialFunctions", "Statistics"]
git-tree-sha1 = "3e03979d16275ed5d9078d50327332c546e24e68"
uuid = "717857b8-e6f2-59f4-9121-6e50c889abd2"
version = "0.7.5"

[[deps.DataAPI]]
git-tree-sha1 = "cc70b17275652eb47bc9e5f81635981f13cea5c8"
uuid = "9a962f9c-6df0-11e9-0e5d-c546b8b5ee8a"
version = "1.9.0"

[[deps.DataFrames]]
deps = ["Compat", "DataAPI", "Future", "InvertedIndices", "IteratorInterfaceExtensions", "LinearAlgebra", "Markdown", "Missings", "PooledArrays", "PrettyTables", "Printf", "REPL", "Reexport", "SortingAlgorithms", "Statistics", "TableTraits", "Tables", "Unicode"]
git-tree-sha1 = "ae02104e835f219b8930c7664b8012c93475c340"
uuid = "a93c6f00-e57d-5684-b7b6-d8193f3e46c0"
version = "1.3.2"

[[deps.DataStructures]]
deps = ["Compat", "InteractiveUtils", "OrderedCollections"]
git-tree-sha1 = "3daef5523dd2e769dad2365274f760ff5f282c7d"
uuid = "864edb3b-99cc-5e75-8d2d-829cb0a9cfe8"
version = "0.18.11"

[[deps.DataValueInterfaces]]
git-tree-sha1 = "bfc1187b79289637fa0ef6d4436ebdfe6905cbd6"
uuid = "e2d170a0-9d28-54be-80f0-106bbe20a464"
version = "1.0.0"

[[deps.Dates]]
deps = ["Printf"]
uuid = "ade2ca70-3891-5945-98fb-dc099432e06a"

[[deps.DelimitedFiles]]
deps = ["Mmap"]
uuid = "8bb1440f-4735-579b-a4ab-409b98df4dab"

[[deps.DensityInterface]]
deps = ["InverseFunctions", "Test"]
git-tree-sha1 = "80c3e8639e3353e5d2912fb3a1916b8455e2494b"
uuid = "b429d917-457f-4dbc-8f4c-0cc954292b1d"
version = "0.4.0"

[[deps.DiffResults]]
deps = ["StaticArrays"]
git-tree-sha1 = "c18e98cba888c6c25d1c3b048e4b3380ca956805"
uuid = "163ba53b-c6d8-5494-b064-1a9d43ac40c5"
version = "1.0.3"

[[deps.DiffRules]]
deps = ["IrrationalConstants", "LogExpFunctions", "NaNMath", "Random", "SpecialFunctions"]
git-tree-sha1 = "dd933c4ef7b4c270aacd4eb88fa64c147492acf0"
uuid = "b552c78f-8df3-52c6-915a-8e097449b14b"
version = "1.10.0"

[[deps.Distances]]
deps = ["LinearAlgebra", "SparseArrays", "Statistics", "StatsAPI"]
git-tree-sha1 = "3258d0659f812acde79e8a74b11f17ac06d0ca04"
uuid = "b4f34e82-e78d-54a5-968a-f98e89d6e8f7"
version = "0.10.7"

[[deps.Distributed]]
deps = ["Random", "Serialization", "Sockets"]
uuid = "8ba89e20-285c-5b6f-9357-94700520ee1b"

[[deps.Distributions]]
deps = ["ChainRulesCore", "DensityInterface", "FillArrays", "LinearAlgebra", "PDMats", "Printf", "QuadGK", "Random", "SparseArrays", "SpecialFunctions", "Statistics", "StatsBase", "StatsFuns", "Test"]
git-tree-sha1 = "5a4168170ede913a2cd679e53c2123cb4b889795"
uuid = "31c24e10-a181-5473-b8eb-7969acd0382f"
version = "0.25.53"

[[deps.DocStringExtensions]]
deps = ["LibGit2"]
git-tree-sha1 = "b19534d1895d702889b219c382a6e18010797f0b"
uuid = "ffbed154-4ef7-542d-bbb7-c09d3a79fcae"
version = "0.8.6"

[[deps.Downloads]]
deps = ["ArgTools", "LibCURL", "NetworkOptions"]
uuid = "f43a241f-c20a-4ad4-852c-f6b1247861c6"

[[deps.DualNumbers]]
deps = ["Calculus", "NaNMath", "SpecialFunctions"]
git-tree-sha1 = "5837a837389fccf076445fce071c8ddaea35a566"
uuid = "fa6b7ba4-c1ee-5f82-b5fc-ecf0adba8f74"
version = "0.6.8"

[[deps.EarCut_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "3f3a2501fa7236e9b911e0f7a588c657e822bb6d"
uuid = "5ae413db-bbd1-5e63-b57d-d24a61df00f5"
version = "2.2.3+0"

[[deps.EllipsisNotation]]
deps = ["ArrayInterface"]
git-tree-sha1 = "d064b0340db45d48893e7604ec95e7a2dc9da904"
uuid = "da5c29d0-fa7d-589e-88eb-ea29b0a81949"
version = "1.5.0"

[[deps.Expat_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "bad72f730e9e91c08d9427d5e8db95478a3c323d"
uuid = "2e619515-83b5-522b-bb60-26c02a35a201"
version = "2.4.8+0"

[[deps.FFMPEG]]
deps = ["FFMPEG_jll"]
git-tree-sha1 = "b57e3acbe22f8484b4b5ff66a7499717fe1a9cc8"
uuid = "c87230d0-a227-11e9-1b43-d7ebe4e7570a"
version = "0.4.1"

[[deps.FFMPEG_jll]]
deps = ["Artifacts", "Bzip2_jll", "FreeType2_jll", "FriBidi_jll", "JLLWrappers", "LAME_jll", "Libdl", "Ogg_jll", "OpenSSL_jll", "Opus_jll", "Pkg", "Zlib_jll", "libass_jll", "libfdk_aac_jll", "libvorbis_jll", "x264_jll", "x265_jll"]
git-tree-sha1 = "d8a578692e3077ac998b50c0217dfd67f21d1e5f"
uuid = "b22a6f82-2f65-5046-a5b2-351ab43fb4e5"
version = "4.4.0+0"

[[deps.FFTViews]]
deps = ["CustomUnitRanges", "FFTW"]
git-tree-sha1 = "cbdf14d1e8c7c8aacbe8b19862e0179fd08321c2"
uuid = "4f61f5a4-77b1-5117-aa51-3ab5ef4ef0cd"
version = "0.3.2"

[[deps.FFTW]]
deps = ["AbstractFFTs", "FFTW_jll", "LinearAlgebra", "MKL_jll", "Preferences", "Reexport"]
git-tree-sha1 = "505876577b5481e50d089c1c68899dfb6faebc62"
uuid = "7a1cc6ca-52ef-59f5-83cd-3a7055c09341"
version = "1.4.6"

[[deps.FFTW_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "c6033cc3892d0ef5bb9cd29b7f2f0331ea5184ea"
uuid = "f5851436-0d7a-5f13-b9de-f02708fd171a"
version = "3.3.10+0"

[[deps.FileIO]]
deps = ["Pkg", "Requires", "UUIDs"]
git-tree-sha1 = "80ced645013a5dbdc52cf70329399c35ce007fae"
uuid = "5789e2e9-d7fb-5bc7-8068-2c6fae9b9549"
version = "1.13.0"

[[deps.FilePathsBase]]
deps = ["Compat", "Dates", "Mmap", "Printf", "Test", "UUIDs"]
git-tree-sha1 = "129b104185df66e408edd6625d480b7f9e9823a0"
uuid = "48062228-2e41-5def-b9a4-89aafe57970f"
version = "0.9.18"

[[deps.FillArrays]]
deps = ["LinearAlgebra", "Random", "SparseArrays", "Statistics"]
git-tree-sha1 = "246621d23d1f43e3b9c368bf3b72b2331a27c286"
uuid = "1a297f60-69ca-5386-bcde-b61e274b549b"
version = "0.13.2"

[[deps.FiniteDiff]]
deps = ["ArrayInterface", "LinearAlgebra", "Requires", "SparseArrays", "StaticArrays"]
git-tree-sha1 = "56956d1e4c1221000b7781104c58c34019792951"
uuid = "6a86dc24-6348-571c-b903-95158fe2bd41"
version = "2.11.0"

[[deps.FixedPointNumbers]]
deps = ["Statistics"]
git-tree-sha1 = "335bfdceacc84c5cdf16aadc768aa5ddfc5383cc"
uuid = "53c48c17-4a7d-5ca2-90c5-79b7896eea93"
version = "0.8.4"

[[deps.Fontconfig_jll]]
deps = ["Artifacts", "Bzip2_jll", "Expat_jll", "FreeType2_jll", "JLLWrappers", "Libdl", "Libuuid_jll", "Pkg", "Zlib_jll"]
git-tree-sha1 = "21efd19106a55620a188615da6d3d06cd7f6ee03"
uuid = "a3f928ae-7b40-5064-980b-68af3947d34b"
version = "2.13.93+0"

[[deps.Formatting]]
deps = ["Printf"]
git-tree-sha1 = "8339d61043228fdd3eb658d86c926cb282ae72a8"
uuid = "59287772-0a20-5a39-b81b-1366585eb4c0"
version = "0.4.2"

[[deps.ForwardDiff]]
deps = ["CommonSubexpressions", "DiffResults", "DiffRules", "LinearAlgebra", "LogExpFunctions", "NaNMath", "Preferences", "Printf", "Random", "SpecialFunctions", "StaticArrays"]
git-tree-sha1 = "1bd6fc0c344fc0cbee1f42f8d2e7ec8253dda2d2"
uuid = "f6369f11-7733-5829-9624-2563aa707210"
version = "0.10.25"

[[deps.FreeType2_jll]]
deps = ["Artifacts", "Bzip2_jll", "JLLWrappers", "Libdl", "Pkg", "Zlib_jll"]
git-tree-sha1 = "87eb71354d8ec1a96d4a7636bd57a7347dde3ef9"
uuid = "d7e528f0-a631-5988-bf34-fe36492bcfd7"
version = "2.10.4+0"

[[deps.FriBidi_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "aa31987c2ba8704e23c6c8ba8a4f769d5d7e4f91"
uuid = "559328eb-81f9-559d-9380-de523a88c83c"
version = "1.0.10+0"

[[deps.Future]]
deps = ["Random"]
uuid = "9fa8497b-333b-5362-9e8d-4d0656e87820"

[[deps.GLFW_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Libglvnd_jll", "Pkg", "Xorg_libXcursor_jll", "Xorg_libXi_jll", "Xorg_libXinerama_jll", "Xorg_libXrandr_jll"]
git-tree-sha1 = "51d2dfe8e590fbd74e7a842cf6d13d8a2f45dc01"
uuid = "0656b61e-2033-5cc2-a64a-77c0f6c09b89"
version = "3.3.6+0"

[[deps.GR]]
deps = ["Base64", "DelimitedFiles", "GR_jll", "HTTP", "JSON", "Libdl", "LinearAlgebra", "Pkg", "Printf", "Random", "RelocatableFolders", "Serialization", "Sockets", "Test", "UUIDs"]
git-tree-sha1 = "af237c08bda486b74318c8070adb96efa6952530"
uuid = "28b8d3ca-fb5f-59d9-8090-bfdbd6d07a71"
version = "0.64.2"

[[deps.GR_jll]]
deps = ["Artifacts", "Bzip2_jll", "Cairo_jll", "FFMPEG_jll", "Fontconfig_jll", "GLFW_jll", "JLLWrappers", "JpegTurbo_jll", "Libdl", "Libtiff_jll", "Pixman_jll", "Pkg", "Qt5Base_jll", "Zlib_jll", "libpng_jll"]
git-tree-sha1 = "cd6efcf9dc746b06709df14e462f0a3fe0786b1e"
uuid = "d2c73de3-f751-5644-a686-071e5b155ba9"
version = "0.64.2+0"

[[deps.GeometryBasics]]
deps = ["EarCut_jll", "IterTools", "LinearAlgebra", "StaticArrays", "StructArrays", "Tables"]
git-tree-sha1 = "83ea630384a13fc4f002b77690bc0afeb4255ac9"
uuid = "5c1252a2-5f33-56bf-86c9-59e7332b4326"
version = "0.4.2"

[[deps.Gettext_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "JLLWrappers", "Libdl", "Libiconv_jll", "Pkg", "XML2_jll"]
git-tree-sha1 = "9b02998aba7bf074d14de89f9d37ca24a1a0b046"
uuid = "78b55507-aeef-58d4-861c-77aaff3498b1"
version = "0.21.0+0"

[[deps.Ghostscript_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "78e2c69783c9753a91cdae88a8d432be85a2ab5e"
uuid = "61579ee1-b43e-5ca0-a5da-69d92c66a64b"
version = "9.55.0+0"

[[deps.Glib_jll]]
deps = ["Artifacts", "Gettext_jll", "JLLWrappers", "Libdl", "Libffi_jll", "Libiconv_jll", "Libmount_jll", "PCRE_jll", "Pkg", "Zlib_jll"]
git-tree-sha1 = "a32d672ac2c967f3deb8a81d828afc739c838a06"
uuid = "7746bdde-850d-59dc-9ae8-88ece973131d"
version = "2.68.3+2"

[[deps.Glob]]
git-tree-sha1 = "4df9f7e06108728ebf00a0a11edee4b29a482bb2"
uuid = "c27321d9-0574-5035-807b-f59d2c89b15c"
version = "1.3.0"

[[deps.Graphics]]
deps = ["Colors", "LinearAlgebra", "NaNMath"]
git-tree-sha1 = "1c5a84319923bea76fa145d49e93aa4394c73fc2"
uuid = "a2bd30eb-e257-5431-a919-1863eab51364"
version = "1.1.1"

[[deps.Graphite2_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "344bf40dcab1073aca04aa0df4fb092f920e4011"
uuid = "3b182d85-2403-5c21-9c21-1e1f0cc25472"
version = "1.3.14+0"

[[deps.Graphs]]
deps = ["ArnoldiMethod", "Compat", "DataStructures", "Distributed", "Inflate", "LinearAlgebra", "Random", "SharedArrays", "SimpleTraits", "SparseArrays", "Statistics"]
git-tree-sha1 = "57c021de207e234108a6f1454003120a1bf350c4"
uuid = "86223c79-3864-5bf0-83f7-82e725a168b6"
version = "1.6.0"

[[deps.Grisu]]
git-tree-sha1 = "53bb909d1151e57e2484c3d1b53e19552b887fb2"
uuid = "42e2da0e-8278-4e71-bc24-59509adca0fe"
version = "1.0.2"

[[deps.HTTP]]
deps = ["Base64", "Dates", "IniFile", "Logging", "MbedTLS", "NetworkOptions", "Sockets", "URIs"]
git-tree-sha1 = "0fa77022fe4b511826b39c894c90daf5fce3334a"
uuid = "cd3eb016-35fb-5094-929b-558a96fad6f3"
version = "0.9.17"

[[deps.HarfBuzz_jll]]
deps = ["Artifacts", "Cairo_jll", "Fontconfig_jll", "FreeType2_jll", "Glib_jll", "Graphite2_jll", "JLLWrappers", "Libdl", "Libffi_jll", "Pkg"]
git-tree-sha1 = "129acf094d168394e80ee1dc4bc06ec835e510a3"
uuid = "2e76f6c2-a576-52d4-95c1-20adfe4de566"
version = "2.8.1+1"

[[deps.HypergeometricFunctions]]
deps = ["DualNumbers", "LinearAlgebra", "SpecialFunctions", "Test"]
git-tree-sha1 = "65e4589030ef3c44d3b90bdc5aac462b4bb05567"
uuid = "34004b35-14d8-5ef3-9330-4cdb6864b03a"
version = "0.3.8"

[[deps.Hyperscript]]
deps = ["Test"]
git-tree-sha1 = "8d511d5b81240fc8e6802386302675bdf47737b9"
uuid = "47d2ed2b-36de-50cf-bf87-49c2cf4b8b91"
version = "0.0.4"

[[deps.HypertextLiteral]]
git-tree-sha1 = "2b078b5a615c6c0396c77810d92ee8c6f470d238"
uuid = "ac1192a8-f4b3-4bfe-ba22-af5b92cd3ab2"
version = "0.9.3"

[[deps.IOCapture]]
deps = ["Logging", "Random"]
git-tree-sha1 = "f7be53659ab06ddc986428d3a9dcc95f6fa6705a"
uuid = "b5f81e59-6552-4d32-b1f0-c071b021bf89"
version = "0.2.2"

[[deps.IfElse]]
git-tree-sha1 = "debdd00ffef04665ccbb3e150747a77560e8fad1"
uuid = "615f187c-cbe4-4ef1-ba3b-2fcf58d6d173"
version = "0.1.1"

[[deps.ImageAxes]]
deps = ["AxisArrays", "ImageBase", "ImageCore", "Reexport", "SimpleTraits"]
git-tree-sha1 = "c54b581a83008dc7f292e205f4c409ab5caa0f04"
uuid = "2803e5a7-5153-5ecf-9a86-9b4c37f5f5ac"
version = "0.6.10"

[[deps.ImageBase]]
deps = ["ImageCore", "Reexport"]
git-tree-sha1 = "b51bb8cae22c66d0f6357e3bcb6363145ef20835"
uuid = "c817782e-172a-44cc-b673-b171935fbb9e"
version = "0.1.5"

[[deps.ImageContrastAdjustment]]
deps = ["ImageCore", "ImageTransformations", "Parameters"]
git-tree-sha1 = "0d75cafa80cf22026cea21a8e6cf965295003edc"
uuid = "f332f351-ec65-5f6a-b3d1-319c6670881a"
version = "0.3.10"

[[deps.ImageCore]]
deps = ["AbstractFFTs", "ColorVectorSpace", "Colors", "FixedPointNumbers", "Graphics", "MappedArrays", "MosaicViews", "OffsetArrays", "PaddedViews", "Reexport"]
git-tree-sha1 = "9a5c62f231e5bba35695a20988fc7cd6de7eeb5a"
uuid = "a09fc81d-aa75-5fe9-8630-4744c3626534"
version = "0.9.3"

[[deps.ImageDistances]]
deps = ["Distances", "ImageCore", "ImageMorphology", "LinearAlgebra", "Statistics"]
git-tree-sha1 = "7a20463713d239a19cbad3f6991e404aca876bda"
uuid = "51556ac3-7006-55f5-8cb3-34580c88182d"
version = "0.2.15"

[[deps.ImageFiltering]]
deps = ["CatIndices", "ComputationalResources", "DataStructures", "FFTViews", "FFTW", "ImageBase", "ImageCore", "LinearAlgebra", "OffsetArrays", "Reexport", "SparseArrays", "StaticArrays", "Statistics", "TiledIteration"]
git-tree-sha1 = "15bd05c1c0d5dbb32a9a3d7e0ad2d50dd6167189"
uuid = "6a3955dd-da59-5b1f-98d4-e7296123deb5"
version = "0.7.1"

[[deps.ImageIO]]
deps = ["FileIO", "JpegTurbo", "Netpbm", "OpenEXR", "PNGFiles", "QOI", "Sixel", "TiffImages", "UUIDs"]
git-tree-sha1 = "464bdef044df52e6436f8c018bea2d48c40bb27b"
uuid = "82e4d734-157c-48bb-816b-45c225c6df19"
version = "0.6.1"

[[deps.ImageMagick]]
deps = ["FileIO", "ImageCore", "ImageMagick_jll", "InteractiveUtils", "Libdl", "Pkg", "Random"]
git-tree-sha1 = "5bc1cb62e0c5f1005868358db0692c994c3a13c6"
uuid = "6218d12a-5da1-5696-b52f-db25d2ecc6d1"
version = "1.2.1"

[[deps.ImageMagick_jll]]
deps = ["Artifacts", "Ghostscript_jll", "JLLWrappers", "JpegTurbo_jll", "Libdl", "Libtiff_jll", "Pkg", "Zlib_jll", "libpng_jll"]
git-tree-sha1 = "f025b79883f361fa1bd80ad132773161d231fd9f"
uuid = "c73af94c-d91f-53ed-93a7-00f77d67a9d7"
version = "6.9.12+2"

[[deps.ImageMetadata]]
deps = ["AxisArrays", "ImageAxes", "ImageBase", "ImageCore"]
git-tree-sha1 = "36cbaebed194b292590cba2593da27b34763804a"
uuid = "bc367c6b-8a6b-528e-b4bd-a4b897500b49"
version = "0.9.8"

[[deps.ImageMorphology]]
deps = ["ImageCore", "LinearAlgebra", "Requires", "TiledIteration"]
git-tree-sha1 = "7668b123ecfd39a6ae3fc31c532b588999bdc166"
uuid = "787d08f9-d448-5407-9aad-5290dd7ab264"
version = "0.3.1"

[[deps.ImageQualityIndexes]]
deps = ["ImageContrastAdjustment", "ImageCore", "ImageDistances", "ImageFiltering", "OffsetArrays", "Statistics"]
git-tree-sha1 = "1d2d73b14198d10f7f12bf7f8481fd4b3ff5cd61"
uuid = "2996bd0c-7a13-11e9-2da2-2f5ce47296a9"
version = "0.3.0"

[[deps.ImageSegmentation]]
deps = ["Clustering", "DataStructures", "Distances", "Graphs", "ImageCore", "ImageFiltering", "ImageMorphology", "LinearAlgebra", "MetaGraphs", "RegionTrees", "SimpleWeightedGraphs", "StaticArrays", "Statistics"]
git-tree-sha1 = "36832067ea220818d105d718527d6ed02385bf22"
uuid = "80713f31-8817-5129-9cf8-209ff8fb23e1"
version = "1.7.0"

[[deps.ImageShow]]
deps = ["Base64", "FileIO", "ImageBase", "ImageCore", "OffsetArrays", "StackViews"]
git-tree-sha1 = "d0ac64c9bee0aed6fdbb2bc0e5dfa9a3a78e3acc"
uuid = "4e3cecfd-b093-5904-9786-8bbb286a6a31"
version = "0.3.3"

[[deps.ImageTransformations]]
deps = ["AxisAlgorithms", "ColorVectorSpace", "CoordinateTransformations", "ImageBase", "ImageCore", "Interpolations", "OffsetArrays", "Rotations", "StaticArrays"]
git-tree-sha1 = "42fe8de1fe1f80dab37a39d391b6301f7aeaa7b8"
uuid = "02fcd773-0e25-5acc-982a-7f6622650795"
version = "0.9.4"

[[deps.Images]]
deps = ["Base64", "FileIO", "Graphics", "ImageAxes", "ImageBase", "ImageContrastAdjustment", "ImageCore", "ImageDistances", "ImageFiltering", "ImageIO", "ImageMagick", "ImageMetadata", "ImageMorphology", "ImageQualityIndexes", "ImageSegmentation", "ImageShow", "ImageTransformations", "IndirectArrays", "IntegralArrays", "Random", "Reexport", "SparseArrays", "StaticArrays", "Statistics", "StatsBase", "TiledIteration"]
git-tree-sha1 = "11d268adba1869067620659e7cdf07f5e54b6c76"
uuid = "916415d5-f1e6-5110-898d-aaa5f9f070e0"
version = "0.25.1"

[[deps.Imath_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "87f7662e03a649cffa2e05bf19c303e168732d3e"
uuid = "905a6f67-0a94-5f89-b386-d35d92009cd1"
version = "3.1.2+0"

[[deps.IndirectArrays]]
git-tree-sha1 = "012e604e1c7458645cb8b436f8fba789a51b257f"
uuid = "9b13fd28-a010-5f03-acff-a1bbcff69959"
version = "1.0.0"

[[deps.Inflate]]
git-tree-sha1 = "f5fc07d4e706b84f72d54eedcc1c13d92fb0871c"
uuid = "d25df0c9-e2be-5dd7-82c8-3ad0b3e990b9"
version = "0.1.2"

[[deps.IniFile]]
git-tree-sha1 = "f550e6e32074c939295eb5ea6de31849ac2c9625"
uuid = "83e8ac13-25f8-5344-8a64-a9f2b223428f"
version = "0.5.1"

[[deps.InlineStrings]]
deps = ["Parsers"]
git-tree-sha1 = "61feba885fac3a407465726d0c330b3055df897f"
uuid = "842dd82b-1e85-43dc-bf29-5d0ee9dffc48"
version = "1.1.2"

[[deps.IntegralArrays]]
deps = ["ColorTypes", "FixedPointNumbers", "IntervalSets"]
git-tree-sha1 = "cf737764159c66b95cdbf5c10484929b247fecfe"
uuid = "1d092043-8f09-5a30-832f-7509e371ab51"
version = "0.1.3"

[[deps.IntelOpenMP_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "d979e54b71da82f3a65b62553da4fc3d18c9004c"
uuid = "1d5cc7b8-4909-519e-a0f8-d0f5ad9712d0"
version = "2018.0.3+2"

[[deps.InteractiveUtils]]
deps = ["Markdown"]
uuid = "b77e0a4c-d291-57a0-90e8-8db25a27a240"

[[deps.Interpolations]]
deps = ["AxisAlgorithms", "ChainRulesCore", "LinearAlgebra", "OffsetArrays", "Random", "Ratios", "Requires", "SharedArrays", "SparseArrays", "StaticArrays", "WoodburyMatrices"]
git-tree-sha1 = "b15fc0a95c564ca2e0a7ae12c1f095ca848ceb31"
uuid = "a98d9a8b-a2ab-59e6-89dd-64a1c18fca59"
version = "0.13.5"

[[deps.IntervalSets]]
deps = ["Dates", "EllipsisNotation", "Statistics"]
git-tree-sha1 = "bcf640979ee55b652f3b01650444eb7bbe3ea837"
uuid = "8197267c-284f-5f27-9208-e0e47529a953"
version = "0.5.4"

[[deps.InverseFunctions]]
deps = ["Test"]
git-tree-sha1 = "91b5dcf362c5add98049e6c29ee756910b03051d"
uuid = "3587e190-3f89-42d0-90ee-14403ec27112"
version = "0.1.3"

[[deps.InvertedIndices]]
git-tree-sha1 = "bee5f1ef5bf65df56bdd2e40447590b272a5471f"
uuid = "41ab1584-1d38-5bbf-9106-f11c6c58b48f"
version = "1.1.0"

[[deps.IrrationalConstants]]
git-tree-sha1 = "7fd44fd4ff43fc60815f8e764c0f352b83c49151"
uuid = "92d709cd-6900-40b7-9082-c6be49f344b6"
version = "0.1.1"

[[deps.IterTools]]
git-tree-sha1 = "fa6287a4469f5e048d763df38279ee729fbd44e5"
uuid = "c8e1da08-722c-5040-9ed9-7db0dc04731e"
version = "1.4.0"

[[deps.IteratorInterfaceExtensions]]
git-tree-sha1 = "a3f24677c21f5bbe9d2a714f95dcd58337fb2856"
uuid = "82899510-4779-5014-852e-03e436cf321d"
version = "1.0.0"

[[deps.JLD2]]
deps = ["FileIO", "MacroTools", "Mmap", "OrderedCollections", "Pkg", "Printf", "Reexport", "TranscodingStreams", "UUIDs"]
git-tree-sha1 = "81b9477b49402b47fbe7f7ae0b252077f53e4a08"
uuid = "033835bb-8acc-5ee8-8aae-3f567f8a3819"
version = "0.4.22"

[[deps.JLLWrappers]]
deps = ["Preferences"]
git-tree-sha1 = "abc9885a7ca2052a736a600f7fa66209f96506e1"
uuid = "692b3bcd-3c85-4b1f-b108-f13ce0eb3210"
version = "1.4.1"

[[deps.JSON]]
deps = ["Dates", "Mmap", "Parsers", "Unicode"]
git-tree-sha1 = "3c837543ddb02250ef42f4738347454f95079d4e"
uuid = "682c06a0-de6a-54ab-a142-c8b1cf79cde6"
version = "0.21.3"

[[deps.JpegTurbo]]
deps = ["CEnum", "FileIO", "ImageCore", "JpegTurbo_jll", "TOML"]
git-tree-sha1 = "a77b273f1ddec645d1b7c4fd5fb98c8f90ad10a5"
uuid = "b835a17e-a41a-41e7-81f0-2f016b05efe0"
version = "0.1.1"

[[deps.JpegTurbo_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "b53380851c6e6664204efb2e62cd24fa5c47e4ba"
uuid = "aacddb02-875f-59d6-b918-886e6ef4fbf8"
version = "2.1.2+0"

[[deps.LAME_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "f6250b16881adf048549549fba48b1161acdac8c"
uuid = "c1c5ebd0-6772-5130-a774-d5fcae4a789d"
version = "3.100.1+0"

[[deps.LERC_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "bf36f528eec6634efc60d7ec062008f171071434"
uuid = "88015f11-f218-50d7-93a8-a6af411a945d"
version = "3.0.0+1"

[[deps.LZO_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "e5b909bcf985c5e2605737d2ce278ed791b89be6"
uuid = "dd4b983a-f0e5-5f8d-a1b7-129d4a5fb1ac"
version = "2.10.1+0"

[[deps.LaTeXStrings]]
git-tree-sha1 = "f2355693d6778a178ade15952b7ac47a4ff97996"
uuid = "b964fa9f-0449-5b57-a5c2-d3ea65f4040f"
version = "1.3.0"

[[deps.Latexify]]
deps = ["Formatting", "InteractiveUtils", "LaTeXStrings", "MacroTools", "Markdown", "Printf", "Requires"]
git-tree-sha1 = "6f14549f7760d84b2db7a9b10b88cd3cc3025730"
uuid = "23fbe1c1-3f47-55db-b15f-69d7ec21a316"
version = "0.15.14"

[[deps.LazyArtifacts]]
deps = ["Artifacts", "Pkg"]
uuid = "4af54fe1-eca0-43a8-85a7-787d91b784e3"

[[deps.LibCURL]]
deps = ["LibCURL_jll", "MozillaCACerts_jll"]
uuid = "b27032c2-a3e7-50c8-80cd-2d36dbcbfd21"

[[deps.LibCURL_jll]]
deps = ["Artifacts", "LibSSH2_jll", "Libdl", "MbedTLS_jll", "Zlib_jll", "nghttp2_jll"]
uuid = "deac9b47-8bc7-5906-a0fe-35ac56dc84c0"

[[deps.LibGit2]]
deps = ["Base64", "NetworkOptions", "Printf", "SHA"]
uuid = "76f85450-5226-5b5a-8eaa-529ad045b433"

[[deps.LibSSH2_jll]]
deps = ["Artifacts", "Libdl", "MbedTLS_jll"]
uuid = "29816b5a-b9ab-546f-933c-edad1886dfa8"

[[deps.Libdl]]
uuid = "8f399da3-3557-5675-b5ff-fb832c97cbdb"

[[deps.Libffi_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "0b4a5d71f3e5200a7dff793393e09dfc2d874290"
uuid = "e9f186c6-92d2-5b65-8a66-fee21dc1b490"
version = "3.2.2+1"

[[deps.Libgcrypt_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Libgpg_error_jll", "Pkg"]
git-tree-sha1 = "64613c82a59c120435c067c2b809fc61cf5166ae"
uuid = "d4300ac3-e22c-5743-9152-c294e39db1e4"
version = "1.8.7+0"

[[deps.Libglvnd_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libX11_jll", "Xorg_libXext_jll"]
git-tree-sha1 = "7739f837d6447403596a75d19ed01fd08d6f56bf"
uuid = "7e76a0d4-f3c7-5321-8279-8d96eeed0f29"
version = "1.3.0+3"

[[deps.Libgpg_error_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "c333716e46366857753e273ce6a69ee0945a6db9"
uuid = "7add5ba3-2f88-524e-9cd5-f83b8a55f7b8"
version = "1.42.0+0"

[[deps.Libiconv_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "42b62845d70a619f063a7da093d995ec8e15e778"
uuid = "94ce4f54-9a6c-5748-9c1c-f9c7231a4531"
version = "1.16.1+1"

[[deps.Libmount_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "9c30530bf0effd46e15e0fdcf2b8636e78cbbd73"
uuid = "4b2f31a3-9ecc-558c-b454-b3730dcb73e9"
version = "2.35.0+0"

[[deps.Libtiff_jll]]
deps = ["Artifacts", "JLLWrappers", "JpegTurbo_jll", "LERC_jll", "Libdl", "Pkg", "Zlib_jll", "Zstd_jll"]
git-tree-sha1 = "c9551dd26e31ab17b86cbd00c2ede019c08758eb"
uuid = "89763e89-9b03-5906-acba-b20f662cd828"
version = "4.3.0+1"

[[deps.Libuuid_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "7f3efec06033682db852f8b3bc3c1d2b0a0ab066"
uuid = "38a345b3-de98-5d2b-a5d3-14cd9215e700"
version = "2.36.0+0"

[[deps.LinearAlgebra]]
deps = ["Libdl", "libblastrampoline_jll"]
uuid = "37e2e46d-f89d-539d-b4ee-838fcccc9c8e"

[[deps.LogExpFunctions]]
deps = ["ChainRulesCore", "ChangesOfVariables", "DocStringExtensions", "InverseFunctions", "IrrationalConstants", "LinearAlgebra"]
git-tree-sha1 = "58f25e56b706f95125dcb796f39e1fb01d913a71"
uuid = "2ab3a3ac-af41-5b50-aa03-7779005ae688"
version = "0.3.10"

[[deps.Logging]]
uuid = "56ddb016-857b-54e1-b83d-db4d58db5568"

[[deps.LsqFit]]
deps = ["Distributions", "ForwardDiff", "LinearAlgebra", "NLSolversBase", "OptimBase", "Random", "StatsBase"]
git-tree-sha1 = "91aa1442e63a77f101aff01dec5a821a17f43922"
uuid = "2fda8390-95c7-5789-9bda-21331edee243"
version = "0.12.1"

[[deps.MKL_jll]]
deps = ["Artifacts", "IntelOpenMP_jll", "JLLWrappers", "LazyArtifacts", "Libdl", "Pkg"]
git-tree-sha1 = "e595b205efd49508358f7dc670a940c790204629"
uuid = "856f044c-d86e-5d09-b602-aeab76dc8ba7"
version = "2022.0.0+0"

[[deps.MacroTools]]
deps = ["Markdown", "Random"]
git-tree-sha1 = "3d3e902b31198a27340d0bf00d6ac452866021cf"
uuid = "1914dd2f-81c6-5fcd-8719-6d5c9610ff09"
version = "0.5.9"

[[deps.MappedArrays]]
git-tree-sha1 = "e8b359ef06ec72e8c030463fe02efe5527ee5142"
uuid = "dbb5928d-eab1-5f90-85c2-b9b0edb7c900"
version = "0.4.1"

[[deps.Markdown]]
deps = ["Base64"]
uuid = "d6f4376e-aef5-505a-96c1-9c027394607a"

[[deps.MbedTLS]]
deps = ["Dates", "MbedTLS_jll", "Random", "Sockets"]
git-tree-sha1 = "1c38e51c3d08ef2278062ebceade0e46cefc96fe"
uuid = "739be429-bea8-5141-9913-cc70e7f3736d"
version = "1.0.3"

[[deps.MbedTLS_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "c8ffd9c3-330d-5841-b78e-0817d7145fa1"

[[deps.Measurements]]
deps = ["Calculus", "LinearAlgebra", "Printf", "RecipesBase", "Requires"]
git-tree-sha1 = "88cd033eb781c698e75ae0b680e5cef1553f0856"
uuid = "eff96d63-e80a-5855-80a2-b1b0885c5ab7"
version = "2.7.1"

[[deps.Measures]]
git-tree-sha1 = "e498ddeee6f9fdb4551ce855a46f54dbd900245f"
uuid = "442fdcdd-2543-5da2-b0f3-8c86c306513e"
version = "0.3.1"

[[deps.MetaGraphs]]
deps = ["Graphs", "JLD2", "Random"]
git-tree-sha1 = "2af69ff3c024d13bde52b34a2a7d6887d4e7b438"
uuid = "626554b9-1ddb-594c-aa3c-2596fe9399a5"
version = "0.7.1"

[[deps.Missings]]
deps = ["DataAPI"]
git-tree-sha1 = "bf210ce90b6c9eed32d25dbcae1ebc565df2687f"
uuid = "e1d29d7a-bbdc-5cf2-9ac0-f12de2c33e28"
version = "1.0.2"

[[deps.Mmap]]
uuid = "a63ad114-7e13-5084-954f-fe012c677804"

[[deps.MosaicViews]]
deps = ["MappedArrays", "OffsetArrays", "PaddedViews", "StackViews"]
git-tree-sha1 = "b34e3bc3ca7c94914418637cb10cc4d1d80d877d"
uuid = "e94cdb99-869f-56ef-bcf0-1ae2bcbe0389"
version = "0.3.3"

[[deps.MozillaCACerts_jll]]
uuid = "14a3606d-f60d-562e-9121-12d972cd8159"

[[deps.MutableArithmetics]]
deps = ["LinearAlgebra", "SparseArrays", "Test"]
git-tree-sha1 = "ba8c0f8732a24facba709388c74ba99dcbfdda1e"
uuid = "d8a4904e-b15c-11e9-3269-09a3773c0cb0"
version = "1.0.0"

[[deps.NLSolversBase]]
deps = ["DiffResults", "Distributed", "FiniteDiff", "ForwardDiff"]
git-tree-sha1 = "50310f934e55e5ca3912fb941dec199b49ca9b68"
uuid = "d41bc354-129a-5804-8e4c-c37616107c6c"
version = "7.8.2"

[[deps.NaNMath]]
git-tree-sha1 = "b086b7ea07f8e38cf122f5016af580881ac914fe"
uuid = "77ba4419-2d1f-58cd-9bb1-8ffee604a2e3"
version = "0.3.7"

[[deps.NearestNeighbors]]
deps = ["Distances", "StaticArrays"]
git-tree-sha1 = "ded92de95031d4a8c61dfb6ba9adb6f1d8016ddd"
uuid = "b8a86587-4115-5ab1-83bc-aa920d37bbce"
version = "0.4.10"

[[deps.Netpbm]]
deps = ["FileIO", "ImageCore"]
git-tree-sha1 = "18efc06f6ec36a8b801b23f076e3c6ac7c3bf153"
uuid = "f09324ee-3d7c-5217-9330-fc30815ba969"
version = "1.0.2"

[[deps.NetworkOptions]]
uuid = "ca575930-c2e3-43a9-ace4-1e988b2c1908"

[[deps.OffsetArrays]]
deps = ["Adapt"]
git-tree-sha1 = "043017e0bdeff61cfbb7afeb558ab29536bbb5ed"
uuid = "6fe1bfb0-de20-5000-8ca7-80f57d26f881"
version = "1.10.8"

[[deps.Ogg_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "887579a3eb005446d514ab7aeac5d1d027658b8f"
uuid = "e7412a2a-1a6e-54c0-be00-318e2571c051"
version = "1.3.5+1"

[[deps.OpenBLAS_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "Libdl"]
uuid = "4536629a-c528-5b80-bd46-f80d51c5b363"

[[deps.OpenEXR]]
deps = ["Colors", "FileIO", "OpenEXR_jll"]
git-tree-sha1 = "327f53360fdb54df7ecd01e96ef1983536d1e633"
uuid = "52e1d378-f018-4a11-a4be-720524705ac7"
version = "0.3.2"

[[deps.OpenEXR_jll]]
deps = ["Artifacts", "Imath_jll", "JLLWrappers", "Libdl", "Pkg", "Zlib_jll"]
git-tree-sha1 = "923319661e9a22712f24596ce81c54fc0366f304"
uuid = "18a262bb-aa17-5467-a713-aee519bc75cb"
version = "3.1.1+0"

[[deps.OpenLibm_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "05823500-19ac-5b8b-9628-191a04bc5112"

[[deps.OpenSSL_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "ab05aa4cc89736e95915b01e7279e61b1bfe33b8"
uuid = "458c3c95-2e84-50aa-8efc-19380b2a3a95"
version = "1.1.14+0"

[[deps.OpenSpecFun_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "13652491f6856acfd2db29360e1bbcd4565d04f1"
uuid = "efe28fd5-8261-553b-a9e1-b2916fc3738e"
version = "0.5.5+0"

[[deps.OptimBase]]
deps = ["NLSolversBase", "Printf", "Reexport"]
git-tree-sha1 = "9cb1fee807b599b5f803809e85c81b582d2009d6"
uuid = "87e2bd06-a317-5318-96d9-3ecbac512eee"
version = "2.0.2"

[[deps.Opus_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "51a08fb14ec28da2ec7a927c4337e4332c2a4720"
uuid = "91d4177d-7536-5919-b921-800302f37372"
version = "1.3.2+0"

[[deps.OrderedCollections]]
git-tree-sha1 = "85f8e6578bf1f9ee0d11e7bb1b1456435479d47c"
uuid = "bac558e1-5e72-5ebc-8fee-abe8a469f55d"
version = "1.4.1"

[[deps.PCRE_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "b2a7af664e098055a7529ad1a900ded962bca488"
uuid = "2f80f16e-611a-54ab-bc61-aa92de5b98fc"
version = "8.44.0+0"

[[deps.PDMats]]
deps = ["LinearAlgebra", "SparseArrays", "SuiteSparse"]
git-tree-sha1 = "e8185b83b9fc56eb6456200e873ce598ebc7f262"
uuid = "90014a1f-27ba-587c-ab20-58faa44d9150"
version = "0.11.7"

[[deps.PNGFiles]]
deps = ["Base64", "CEnum", "ImageCore", "IndirectArrays", "OffsetArrays", "libpng_jll"]
git-tree-sha1 = "eb4dbb8139f6125471aa3da98fb70f02dc58e49c"
uuid = "f57f5aa1-a3ce-4bc8-8ab9-96f992907883"
version = "0.3.14"

[[deps.PaddedViews]]
deps = ["OffsetArrays"]
git-tree-sha1 = "03a7a85b76381a3d04c7a1656039197e70eda03d"
uuid = "5432bcbf-9aad-5242-b902-cca2824c8663"
version = "0.5.11"

[[deps.Parameters]]
deps = ["OrderedCollections", "UnPack"]
git-tree-sha1 = "34c0e9ad262e5f7fc75b10a9952ca7692cfc5fbe"
uuid = "d96e819e-fc66-5662-9728-84c9c7592b0a"
version = "0.12.3"

[[deps.Parsers]]
deps = ["Dates"]
git-tree-sha1 = "621f4f3b4977325b9128d5fae7a8b4829a0c2222"
uuid = "69de0a69-1ddd-5017-9359-2bf0b02dc9f0"
version = "2.2.4"

[[deps.Peaks]]
deps = ["Compat"]
git-tree-sha1 = "79e1f108ef46e9393bc670440c5f3ec78d23eb78"
uuid = "18e31ff7-3703-566c-8e60-38913d67486b"
version = "0.4.0"

[[deps.PhysicalConstants]]
deps = ["Measurements", "Roots", "Unitful"]
git-tree-sha1 = "2bc26b693b5cbc823c54b33ea88a9209d27e2db7"
uuid = "5ad8b20f-a522-5ce9-bfc9-ddf1d5bda6ab"
version = "0.2.1"

[[deps.Pixman_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "b4f5d02549a10e20780a24fce72bea96b6329e29"
uuid = "30392449-352a-5448-841d-b1acce4e97dc"
version = "0.40.1+0"

[[deps.Pkg]]
deps = ["Artifacts", "Dates", "Downloads", "LibGit2", "Libdl", "Logging", "Markdown", "Printf", "REPL", "Random", "SHA", "Serialization", "TOML", "Tar", "UUIDs", "p7zip_jll"]
uuid = "44cfe95a-1eb2-52ea-b672-e2afdf69b78f"

[[deps.PkgVersion]]
deps = ["Pkg"]
git-tree-sha1 = "a7a7e1a88853564e551e4eba8650f8c38df79b37"
uuid = "eebad327-c553-4316-9ea0-9fa01ccd7688"
version = "0.1.1"

[[deps.PlotThemes]]
deps = ["PlotUtils", "Requires", "Statistics"]
git-tree-sha1 = "a3a964ce9dc7898193536002a6dd892b1b5a6f1d"
uuid = "ccf2f8ad-2431-5c83-bf29-c5338b663b6a"
version = "2.0.1"

[[deps.PlotUtils]]
deps = ["ColorSchemes", "Colors", "Dates", "Printf", "Random", "Reexport", "Statistics"]
git-tree-sha1 = "bb16469fd5224100e422f0b027d26c5a25de1200"
uuid = "995b91a9-d308-5afd-9ec6-746e21dbc043"
version = "1.2.0"

[[deps.Plots]]
deps = ["Base64", "Contour", "Dates", "Downloads", "FFMPEG", "FixedPointNumbers", "GR", "GeometryBasics", "JSON", "Latexify", "LinearAlgebra", "Measures", "NaNMath", "Pkg", "PlotThemes", "PlotUtils", "Printf", "REPL", "Random", "RecipesBase", "RecipesPipeline", "Reexport", "Requires", "Scratch", "Showoff", "SparseArrays", "Statistics", "StatsBase", "UUIDs", "UnicodeFun", "Unzip"]
git-tree-sha1 = "edec0846433f1c1941032385588fd57380b62b59"
uuid = "91a5bcdd-55d7-5caf-9e0b-520d859cae80"
version = "1.27.4"

[[deps.PlutoUI]]
deps = ["AbstractPlutoDingetjes", "Base64", "ColorTypes", "Dates", "Hyperscript", "HypertextLiteral", "IOCapture", "InteractiveUtils", "JSON", "Logging", "Markdown", "Random", "Reexport", "UUIDs"]
git-tree-sha1 = "670e559e5c8e191ded66fa9ea89c97f10376bb4c"
uuid = "7f904dfe-b85e-4ff6-b463-dae2292396a8"
version = "0.7.38"

[[deps.Polynomials]]
deps = ["LinearAlgebra", "MutableArithmetics", "RecipesBase"]
git-tree-sha1 = "0107e2f7f90cc7f756fee8a304987c574bbd7583"
uuid = "f27b6e38-b328-58d1-80ce-0feddd5e7a45"
version = "3.0.0"

[[deps.PooledArrays]]
deps = ["DataAPI", "Future"]
git-tree-sha1 = "28ef6c7ce353f0b35d0df0d5930e0d072c1f5b9b"
uuid = "2dfb63ee-cc39-5dd5-95bd-886bf059d720"
version = "1.4.1"

[[deps.Preferences]]
deps = ["TOML"]
git-tree-sha1 = "d3538e7f8a790dc8903519090857ef8e1283eecd"
uuid = "21216c6a-2e73-6563-6e65-726566657250"
version = "1.2.5"

[[deps.PrettyTables]]
deps = ["Crayons", "Formatting", "Markdown", "Reexport", "Tables"]
git-tree-sha1 = "dfb54c4e414caa595a1f2ed759b160f5a3ddcba5"
uuid = "08abe8d2-0d0c-5749-adfa-8a2ac140af0d"
version = "1.3.1"

[[deps.Printf]]
deps = ["Unicode"]
uuid = "de0858da-6303-5e67-8744-51eddeeeb8d7"

[[deps.ProgressMeter]]
deps = ["Distributed", "Printf"]
git-tree-sha1 = "d7a7aef8f8f2d537104f170139553b14dfe39fe9"
uuid = "92933f4c-e287-5a05-a399-4b506db050ca"
version = "1.7.2"

[[deps.QOI]]
deps = ["ColorTypes", "FileIO", "FixedPointNumbers"]
git-tree-sha1 = "18e8f4d1426e965c7b532ddd260599e1510d26ce"
uuid = "4b34888f-f399-49d4-9bb3-47ed5cae4e65"
version = "1.0.0"

[[deps.Qt5Base_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "Fontconfig_jll", "Glib_jll", "JLLWrappers", "Libdl", "Libglvnd_jll", "OpenSSL_jll", "Pkg", "Xorg_libXext_jll", "Xorg_libxcb_jll", "Xorg_xcb_util_image_jll", "Xorg_xcb_util_keysyms_jll", "Xorg_xcb_util_renderutil_jll", "Xorg_xcb_util_wm_jll", "Zlib_jll", "xkbcommon_jll"]
git-tree-sha1 = "ad368663a5e20dbb8d6dc2fddeefe4dae0781ae8"
uuid = "ea2cea3b-5b76-57ae-a6ef-0a8af62496e1"
version = "5.15.3+0"

[[deps.QuadGK]]
deps = ["DataStructures", "LinearAlgebra"]
git-tree-sha1 = "78aadffb3efd2155af139781b8a8df1ef279ea39"
uuid = "1fd47b50-473d-5c70-9696-f719f8f3bcdc"
version = "2.4.2"

[[deps.Quaternions]]
deps = ["DualNumbers", "LinearAlgebra", "Random"]
git-tree-sha1 = "522770af103809e8346aefa4b25c31fbec377ccf"
uuid = "94ee1d12-ae83-5a48-8b1c-48b8ff168ae0"
version = "0.5.3"

[[deps.REPL]]
deps = ["InteractiveUtils", "Markdown", "Sockets", "Unicode"]
uuid = "3fa0cd96-eef1-5676-8a61-b3b8758bbffb"

[[deps.Random]]
deps = ["SHA", "Serialization"]
uuid = "9a3f8284-a2c9-5f02-9a11-845980a1fd5c"

[[deps.RangeArrays]]
git-tree-sha1 = "b9039e93773ddcfc828f12aadf7115b4b4d225f5"
uuid = "b3c3ace0-ae52-54e7-9d0b-2c1406fd6b9d"
version = "0.3.2"

[[deps.Ratios]]
deps = ["Requires"]
git-tree-sha1 = "dc84268fe0e3335a62e315a3a7cf2afa7178a734"
uuid = "c84ed2f1-dad5-54f0-aa8e-dbefe2724439"
version = "0.4.3"

[[deps.RecipesBase]]
git-tree-sha1 = "6bf3f380ff52ce0832ddd3a2a7b9538ed1bcca7d"
uuid = "3cdcf5f2-1ef4-517c-9805-6587b60abb01"
version = "1.2.1"

[[deps.RecipesPipeline]]
deps = ["Dates", "NaNMath", "PlotUtils", "RecipesBase"]
git-tree-sha1 = "dc1e451e15d90347a7decc4221842a022b011714"
uuid = "01d81517-befc-4cb6-b9ec-a95719d0359c"
version = "0.5.2"

[[deps.Reexport]]
git-tree-sha1 = "45e428421666073eab6f2da5c9d310d99bb12f9b"
uuid = "189a3867-3050-52da-a836-e630ba90ab69"
version = "1.2.2"

[[deps.RegionTrees]]
deps = ["IterTools", "LinearAlgebra", "StaticArrays"]
git-tree-sha1 = "4618ed0da7a251c7f92e869ae1a19c74a7d2a7f9"
uuid = "dee08c22-ab7f-5625-9660-a9af2021b33f"
version = "0.3.2"

[[deps.RelocatableFolders]]
deps = ["SHA", "Scratch"]
git-tree-sha1 = "cdbd3b1338c72ce29d9584fdbe9e9b70eeb5adca"
uuid = "05181044-ff0b-4ac5-8273-598c1e38db00"
version = "0.1.3"

[[deps.Requires]]
deps = ["UUIDs"]
git-tree-sha1 = "838a3a4188e2ded87a4f9f184b4b0d78a1e91cb7"
uuid = "ae029012-a4dd-5104-9daa-d747884805df"
version = "1.3.0"

[[deps.Rmath]]
deps = ["Random", "Rmath_jll"]
git-tree-sha1 = "bf3188feca147ce108c76ad82c2792c57abe7b1f"
uuid = "79098fc4-a85e-5d69-aa6a-4863f24498fa"
version = "0.7.0"

[[deps.Rmath_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "68db32dff12bb6127bac73c209881191bf0efbb7"
uuid = "f50d1b31-88e8-58de-be2c-1cc44531875f"
version = "0.3.0+0"

[[deps.Roots]]
deps = ["CommonSolve", "Printf", "Setfield"]
git-tree-sha1 = "6085b8ac184add45b586ed8d74468310948dcfe8"
uuid = "f2b01f46-fcfa-551c-844a-d8ac1e96c665"
version = "1.4.0"

[[deps.Rotations]]
deps = ["LinearAlgebra", "Quaternions", "Random", "StaticArrays", "Statistics"]
git-tree-sha1 = "a167638e2cbd8ac41f9cd57282cab9b042fa26e6"
uuid = "6038ab10-8711-5258-84ad-4b1120ba62dc"
version = "1.3.0"

[[deps.SHA]]
uuid = "ea8e919c-243c-51af-8825-aaa63cd721ce"

[[deps.Scratch]]
deps = ["Dates"]
git-tree-sha1 = "0b4b7f1393cff97c33891da2a0bf69c6ed241fda"
uuid = "6c6a2e73-6563-6170-7368-637461726353"
version = "1.1.0"

[[deps.SentinelArrays]]
deps = ["Dates", "Random"]
git-tree-sha1 = "6a2f7d70512d205ca8c7ee31bfa9f142fe74310c"
uuid = "91c51154-3ec4-41a3-a24f-3f23e20d615c"
version = "1.3.12"

[[deps.Serialization]]
uuid = "9e88b42a-f829-5b0c-bbe9-9e923198166b"

[[deps.Setfield]]
deps = ["ConstructionBase", "Future", "MacroTools", "Requires"]
git-tree-sha1 = "38d88503f695eb0301479bc9b0d4320b378bafe5"
uuid = "efcf1570-3423-57d1-acb7-fd33fddbac46"
version = "0.8.2"

[[deps.SharedArrays]]
deps = ["Distributed", "Mmap", "Random", "Serialization"]
uuid = "1a1011a3-84de-559e-8e89-a11a2f7dc383"

[[deps.Showoff]]
deps = ["Dates", "Grisu"]
git-tree-sha1 = "91eddf657aca81df9ae6ceb20b959ae5653ad1de"
uuid = "992d4aef-0814-514b-bc4d-f2e9a6c4116f"
version = "1.0.3"

[[deps.SimpleTraits]]
deps = ["InteractiveUtils", "MacroTools"]
git-tree-sha1 = "5d7e3f4e11935503d3ecaf7186eac40602e7d231"
uuid = "699a6c99-e7fa-54fc-8d76-47d257e15c1d"
version = "0.9.4"

[[deps.SimpleWeightedGraphs]]
deps = ["Graphs", "LinearAlgebra", "Markdown", "SparseArrays", "Test"]
git-tree-sha1 = "a6f404cc44d3d3b28c793ec0eb59af709d827e4e"
uuid = "47aef6b3-ad0c-573a-a1e2-d07658019622"
version = "1.2.1"

[[deps.Sixel]]
deps = ["Dates", "FileIO", "ImageCore", "IndirectArrays", "OffsetArrays", "REPL", "libsixel_jll"]
git-tree-sha1 = "8fb59825be681d451c246a795117f317ecbcaa28"
uuid = "45858cf5-a6b0-47a3-bbea-62219f50df47"
version = "0.1.2"

[[deps.Sockets]]
uuid = "6462fe0b-24de-5631-8697-dd941f90decc"

[[deps.SortingAlgorithms]]
deps = ["DataStructures"]
git-tree-sha1 = "b3363d7460f7d098ca0912c69b082f75625d7508"
uuid = "a2af1166-a08f-5f64-846c-94a0d3cef48c"
version = "1.0.1"

[[deps.SparseArrays]]
deps = ["LinearAlgebra", "Random"]
uuid = "2f01184e-e22b-5df5-ae63-d93ebab69eaf"

[[deps.SpecialFunctions]]
deps = ["ChainRulesCore", "IrrationalConstants", "LogExpFunctions", "OpenLibm_jll", "OpenSpecFun_jll"]
git-tree-sha1 = "5ba658aeecaaf96923dce0da9e703bd1fe7666f9"
uuid = "276daf66-3868-5448-9aa4-cd146d93841b"
version = "2.1.4"

[[deps.StackViews]]
deps = ["OffsetArrays"]
git-tree-sha1 = "46e589465204cd0c08b4bd97385e4fa79a0c770c"
uuid = "cae243ae-269e-4f55-b966-ac2d0dc13c15"
version = "0.1.1"

[[deps.Static]]
deps = ["IfElse"]
git-tree-sha1 = "87e9954dfa33fd145694e42337bdd3d5b07021a6"
uuid = "aedffcd0-7271-4cad-89d0-dc628f76c6d3"
version = "0.6.0"

[[deps.StaticArrays]]
deps = ["LinearAlgebra", "Random", "Statistics"]
git-tree-sha1 = "4f6ec5d99a28e1a749559ef7dd518663c5eca3d5"
uuid = "90137ffa-7385-5640-81b9-e52037218182"
version = "1.4.3"

[[deps.Statistics]]
deps = ["LinearAlgebra", "SparseArrays"]
uuid = "10745b16-79ce-11e8-11f9-7d13ad32a3b2"

[[deps.StatsAPI]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "c3d8ba7f3fa0625b062b82853a7d5229cb728b6b"
uuid = "82ae8749-77ed-4fe6-ae5f-f523153014b0"
version = "1.2.1"

[[deps.StatsBase]]
deps = ["DataAPI", "DataStructures", "LinearAlgebra", "LogExpFunctions", "Missings", "Printf", "Random", "SortingAlgorithms", "SparseArrays", "Statistics", "StatsAPI"]
git-tree-sha1 = "8977b17906b0a1cc74ab2e3a05faa16cf08a8291"
uuid = "2913bbd2-ae8a-5f71-8c99-4fb6c76f3a91"
version = "0.33.16"

[[deps.StatsFuns]]
deps = ["ChainRulesCore", "HypergeometricFunctions", "InverseFunctions", "IrrationalConstants", "LogExpFunctions", "Reexport", "Rmath", "SpecialFunctions"]
git-tree-sha1 = "72e6abd6fc9ef0fa62a159713c83b7637a14b2b8"
uuid = "4c63d2b9-4356-54db-8cca-17b64c39e42c"
version = "0.9.17"

[[deps.StructArrays]]
deps = ["Adapt", "DataAPI", "StaticArrays", "Tables"]
git-tree-sha1 = "57617b34fa34f91d536eb265df67c2d4519b8b98"
uuid = "09ab397b-f2b6-538f-b94a-2f83cf4a842a"
version = "0.6.5"

[[deps.SuiteSparse]]
deps = ["Libdl", "LinearAlgebra", "Serialization", "SparseArrays"]
uuid = "4607b0f0-06f3-5cda-b6b1-a6196a1729e9"

[[deps.TOML]]
deps = ["Dates"]
uuid = "fa267f1f-6049-4f14-aa54-33bafae1ed76"

[[deps.TableTraits]]
deps = ["IteratorInterfaceExtensions"]
git-tree-sha1 = "c06b2f539df1c6efa794486abfb6ed2022561a39"
uuid = "3783bdb8-4a98-5b6b-af9a-565f29a5fe9c"
version = "1.0.1"

[[deps.Tables]]
deps = ["DataAPI", "DataValueInterfaces", "IteratorInterfaceExtensions", "LinearAlgebra", "OrderedCollections", "TableTraits", "Test"]
git-tree-sha1 = "5ce79ce186cc678bbb5c5681ca3379d1ddae11a1"
uuid = "bd369af6-aec1-5ad0-b16a-f7cc5008161c"
version = "1.7.0"

[[deps.Tar]]
deps = ["ArgTools", "SHA"]
uuid = "a4e569a6-e804-4fa4-b0f3-eef7a1d5b13e"

[[deps.TensorCore]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "1feb45f88d133a655e001435632f019a9a1bcdb6"
uuid = "62fd8b95-f654-4bbd-a8a5-9c27f68ccd50"
version = "0.1.1"

[[deps.Test]]
deps = ["InteractiveUtils", "Logging", "Random", "Serialization"]
uuid = "8dfed614-e22c-5e08-85e1-65c5234f0b40"

[[deps.TiffImages]]
deps = ["ColorTypes", "DataStructures", "DocStringExtensions", "FileIO", "FixedPointNumbers", "IndirectArrays", "Inflate", "OffsetArrays", "PkgVersion", "ProgressMeter", "UUIDs"]
git-tree-sha1 = "aaa19086bc282630d82f818456bc40b4d314307d"
uuid = "731e570b-9d59-4bfa-96dc-6df516fadf69"
version = "0.5.4"

[[deps.TiledIteration]]
deps = ["OffsetArrays"]
git-tree-sha1 = "5683455224ba92ef59db72d10690690f4a8dc297"
uuid = "06e1c1a7-607b-532d-9fad-de7d9aa2abac"
version = "0.3.1"

[[deps.TranscodingStreams]]
deps = ["Random", "Test"]
git-tree-sha1 = "216b95ea110b5972db65aa90f88d8d89dcb8851c"
uuid = "3bb67fe8-82b1-5028-8e26-92a6c54297fa"
version = "0.9.6"

[[deps.URIs]]
git-tree-sha1 = "97bbe755a53fe859669cd907f2d96aee8d2c1355"
uuid = "5c2747f8-b7ea-4ff2-ba2e-563bfd36b1d4"
version = "1.3.0"

[[deps.UUIDs]]
deps = ["Random", "SHA"]
uuid = "cf7118a7-6976-5b1a-9a39-7adc72f591a4"

[[deps.UnPack]]
git-tree-sha1 = "387c1f73762231e86e0c9c5443ce3b4a0a9a0c2b"
uuid = "3a884ed6-31ef-47d7-9d2a-63182c4928ed"
version = "1.0.2"

[[deps.Unicode]]
uuid = "4ec0a83e-493e-50e2-b9ac-8f72acf5a8f5"

[[deps.UnicodeFun]]
deps = ["REPL"]
git-tree-sha1 = "53915e50200959667e78a92a418594b428dffddf"
uuid = "1cfade01-22cf-5700-b092-accc4b62d6e1"
version = "0.4.1"

[[deps.Unitful]]
deps = ["ConstructionBase", "Dates", "LinearAlgebra", "Random"]
git-tree-sha1 = "b649200e887a487468b71821e2644382699f1b0f"
uuid = "1986cc42-f94f-5a68-af5c-568840ba703d"
version = "1.11.0"

[[deps.UnitfulEquivalences]]
deps = ["Unitful"]
git-tree-sha1 = "76fc2f7fdc87531a1018eb7d647df7c29daf36b7"
uuid = "da9c4bc3-91c8-4f02-8a40-6b990d2a7e0c"
version = "0.2.0"

[[deps.Unzip]]
git-tree-sha1 = "34db80951901073501137bdbc3d5a8e7bbd06670"
uuid = "41fe7b60-77ed-43a1-b4f0-825fd5a5650d"
version = "0.1.2"

[[deps.Wayland_jll]]
deps = ["Artifacts", "Expat_jll", "JLLWrappers", "Libdl", "Libffi_jll", "Pkg", "XML2_jll"]
git-tree-sha1 = "3e61f0b86f90dacb0bc0e73a0c5a83f6a8636e23"
uuid = "a2964d1f-97da-50d4-b82a-358c7fce9d89"
version = "1.19.0+0"

[[deps.Wayland_protocols_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "4528479aa01ee1b3b4cd0e6faef0e04cf16466da"
uuid = "2381bf8a-dfd0-557d-9999-79630e7b1b91"
version = "1.25.0+0"

[[deps.WeakRefStrings]]
deps = ["DataAPI", "InlineStrings", "Parsers"]
git-tree-sha1 = "b1be2855ed9ed8eac54e5caff2afcdb442d52c23"
uuid = "ea10d353-3f73-51f8-a26c-33c1cb351aa5"
version = "1.4.2"

[[deps.WoodburyMatrices]]
deps = ["LinearAlgebra", "SparseArrays"]
git-tree-sha1 = "de67fa59e33ad156a590055375a30b23c40299d3"
uuid = "efce3f68-66dc-5838-9240-27a6d6f5f9b6"
version = "0.5.5"

[[deps.XML2_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Libiconv_jll", "Pkg", "Zlib_jll"]
git-tree-sha1 = "1acf5bdf07aa0907e0a37d3718bb88d4b687b74a"
uuid = "02c8fc9c-b97f-50b9-bbe4-9be30ff0a78a"
version = "2.9.12+0"

[[deps.XSLT_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Libgcrypt_jll", "Libgpg_error_jll", "Libiconv_jll", "Pkg", "XML2_jll", "Zlib_jll"]
git-tree-sha1 = "91844873c4085240b95e795f692c4cec4d805f8a"
uuid = "aed1982a-8fda-507f-9586-7b0439959a61"
version = "1.1.34+0"

[[deps.Xorg_libX11_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libxcb_jll", "Xorg_xtrans_jll"]
git-tree-sha1 = "5be649d550f3f4b95308bf0183b82e2582876527"
uuid = "4f6342f7-b3d2-589e-9d20-edeb45f2b2bc"
version = "1.6.9+4"

[[deps.Xorg_libXau_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "4e490d5c960c314f33885790ed410ff3a94ce67e"
uuid = "0c0b7dd1-d40b-584c-a123-a41640f87eec"
version = "1.0.9+4"

[[deps.Xorg_libXcursor_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libXfixes_jll", "Xorg_libXrender_jll"]
git-tree-sha1 = "12e0eb3bc634fa2080c1c37fccf56f7c22989afd"
uuid = "935fb764-8cf2-53bf-bb30-45bb1f8bf724"
version = "1.2.0+4"

[[deps.Xorg_libXdmcp_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "4fe47bd2247248125c428978740e18a681372dd4"
uuid = "a3789734-cfe1-5b06-b2d0-1dd0d9d62d05"
version = "1.1.3+4"

[[deps.Xorg_libXext_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libX11_jll"]
git-tree-sha1 = "b7c0aa8c376b31e4852b360222848637f481f8c3"
uuid = "1082639a-0dae-5f34-9b06-72781eeb8cb3"
version = "1.3.4+4"

[[deps.Xorg_libXfixes_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libX11_jll"]
git-tree-sha1 = "0e0dc7431e7a0587559f9294aeec269471c991a4"
uuid = "d091e8ba-531a-589c-9de9-94069b037ed8"
version = "5.0.3+4"

[[deps.Xorg_libXi_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libXext_jll", "Xorg_libXfixes_jll"]
git-tree-sha1 = "89b52bc2160aadc84d707093930ef0bffa641246"
uuid = "a51aa0fd-4e3c-5386-b890-e753decda492"
version = "1.7.10+4"

[[deps.Xorg_libXinerama_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libXext_jll"]
git-tree-sha1 = "26be8b1c342929259317d8b9f7b53bf2bb73b123"
uuid = "d1454406-59df-5ea1-beac-c340f2130bc3"
version = "1.1.4+4"

[[deps.Xorg_libXrandr_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libXext_jll", "Xorg_libXrender_jll"]
git-tree-sha1 = "34cea83cb726fb58f325887bf0612c6b3fb17631"
uuid = "ec84b674-ba8e-5d96-8ba1-2a689ba10484"
version = "1.5.2+4"

[[deps.Xorg_libXrender_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libX11_jll"]
git-tree-sha1 = "19560f30fd49f4d4efbe7002a1037f8c43d43b96"
uuid = "ea2f1a96-1ddc-540d-b46f-429655e07cfa"
version = "0.9.10+4"

[[deps.Xorg_libpthread_stubs_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "6783737e45d3c59a4a4c4091f5f88cdcf0908cbb"
uuid = "14d82f49-176c-5ed1-bb49-ad3f5cbd8c74"
version = "0.1.0+3"

[[deps.Xorg_libxcb_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "XSLT_jll", "Xorg_libXau_jll", "Xorg_libXdmcp_jll", "Xorg_libpthread_stubs_jll"]
git-tree-sha1 = "daf17f441228e7a3833846cd048892861cff16d6"
uuid = "c7cfdc94-dc32-55de-ac96-5a1b8d977c5b"
version = "1.13.0+3"

[[deps.Xorg_libxkbfile_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libX11_jll"]
git-tree-sha1 = "926af861744212db0eb001d9e40b5d16292080b2"
uuid = "cc61e674-0454-545c-8b26-ed2c68acab7a"
version = "1.1.0+4"

[[deps.Xorg_xcb_util_image_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_xcb_util_jll"]
git-tree-sha1 = "0fab0a40349ba1cba2c1da699243396ff8e94b97"
uuid = "12413925-8142-5f55-bb0e-6d7ca50bb09b"
version = "0.4.0+1"

[[deps.Xorg_xcb_util_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libxcb_jll"]
git-tree-sha1 = "e7fd7b2881fa2eaa72717420894d3938177862d1"
uuid = "2def613f-5ad1-5310-b15b-b15d46f528f5"
version = "0.4.0+1"

[[deps.Xorg_xcb_util_keysyms_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_xcb_util_jll"]
git-tree-sha1 = "d1151e2c45a544f32441a567d1690e701ec89b00"
uuid = "975044d2-76e6-5fbe-bf08-97ce7c6574c7"
version = "0.4.0+1"

[[deps.Xorg_xcb_util_renderutil_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_xcb_util_jll"]
git-tree-sha1 = "dfd7a8f38d4613b6a575253b3174dd991ca6183e"
uuid = "0d47668e-0667-5a69-a72c-f761630bfb7e"
version = "0.3.9+1"

[[deps.Xorg_xcb_util_wm_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_xcb_util_jll"]
git-tree-sha1 = "e78d10aab01a4a154142c5006ed44fd9e8e31b67"
uuid = "c22f9ab0-d5fe-5066-847c-f4bb1cd4e361"
version = "0.4.1+1"

[[deps.Xorg_xkbcomp_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libxkbfile_jll"]
git-tree-sha1 = "4bcbf660f6c2e714f87e960a171b119d06ee163b"
uuid = "35661453-b289-5fab-8a00-3d9160c6a3a4"
version = "1.4.2+4"

[[deps.Xorg_xkeyboard_config_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_xkbcomp_jll"]
git-tree-sha1 = "5c8424f8a67c3f2209646d4425f3d415fee5931d"
uuid = "33bec58e-1273-512f-9401-5d533626f822"
version = "2.27.0+4"

[[deps.Xorg_xtrans_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "79c31e7844f6ecf779705fbc12146eb190b7d845"
uuid = "c5fb5394-a638-5e4d-96e5-b29de1b5cf10"
version = "1.4.0+3"

[[deps.Zlib_jll]]
deps = ["Libdl"]
uuid = "83775a58-1f1d-513f-b197-d71354ab007a"

[[deps.Zstd_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "e45044cd873ded54b6a5bac0eb5c971392cf1927"
uuid = "3161d3a3-bdf6-5164-811a-617609db77b4"
version = "1.5.2+0"

[[deps.libass_jll]]
deps = ["Artifacts", "Bzip2_jll", "FreeType2_jll", "FriBidi_jll", "HarfBuzz_jll", "JLLWrappers", "Libdl", "Pkg", "Zlib_jll"]
git-tree-sha1 = "5982a94fcba20f02f42ace44b9894ee2b140fe47"
uuid = "0ac62f75-1d6f-5e53-bd7c-93b484bb37c0"
version = "0.15.1+0"

[[deps.libblastrampoline_jll]]
deps = ["Artifacts", "Libdl", "OpenBLAS_jll"]
uuid = "8e850b90-86db-534c-a0d3-1478176c7d93"

[[deps.libfdk_aac_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "daacc84a041563f965be61859a36e17c4e4fcd55"
uuid = "f638f0a6-7fb0-5443-88ba-1cc74229b280"
version = "2.0.2+0"

[[deps.libpng_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Zlib_jll"]
git-tree-sha1 = "94d180a6d2b5e55e447e2d27a29ed04fe79eb30c"
uuid = "b53b4c65-9356-5827-b1ea-8c7a1a84506f"
version = "1.6.38+0"

[[deps.libsixel_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "78736dab31ae7a53540a6b752efc61f77b304c5b"
uuid = "075b6546-f08a-558a-be8f-8157d0f608a5"
version = "1.8.6+1"

[[deps.libvorbis_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Ogg_jll", "Pkg"]
git-tree-sha1 = "b910cb81ef3fe6e78bf6acee440bda86fd6ae00c"
uuid = "f27f6e37-5d2b-51aa-960f-b287f2bc3b7a"
version = "1.3.7+1"

[[deps.nghttp2_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "8e850ede-7688-5339-a07c-302acd2aaf8d"

[[deps.p7zip_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "3f19e933-33d8-53b3-aaab-bd5110c3b7a0"

[[deps.x264_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "4fea590b89e6ec504593146bf8b988b2c00922b2"
uuid = "1270edf5-f2f9-52d2-97e9-ab00b5d0237a"
version = "2021.5.5+0"

[[deps.x265_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "ee567a171cce03570d77ad3a43e90218e38937a9"
uuid = "dfaa095f-4041-5dcd-9319-2fabd8486b76"
version = "3.5.0+0"

[[deps.xkbcommon_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Wayland_jll", "Wayland_protocols_jll", "Xorg_libxcb_jll", "Xorg_xkeyboard_config_jll"]
git-tree-sha1 = "ece2350174195bb31de1a63bea3a41ae1aa593b6"
uuid = "d8fb68d0-12a3-5cfd-a85a-d49703b185fd"
version = "0.9.1+5"
"""

# ╔═╡ Cell order:
# ╠═59062c8d-edbf-4966-a786-724f9438618c
# ╠═547c0f35-243e-4038-bb66-65b627bda4b0
# ╠═9d66c472-b742-49b3-9495-1c3be998108b
# ╠═c3b89fa7-67f8-4cc3-b3ba-fcb304f44669
# ╠═bd9eed27-fc29-41ff-bf12-ec0cd3881ea2
# ╠═ca6f7233-a1d1-403d-9416-835a51d360db
# ╠═ac5daa7a-b00b-4975-906d-f68e455c2b53
# ╠═a8ffd5c7-2a6f-4955-8e9f-ea605a8cb24d
# ╠═ea4b37e5-fc26-4ca3-8788-20dd4c57536c
# ╠═c91bef90-362d-4bc7-8378-2f6dc55a20eb
# ╠═96ae3a10-b116-4544-b282-59b1f58417bf
# ╠═34b3d66e-3b39-43dc-922b-9ba6c15c1bac
# ╠═5927e85d-f206-4d51-9b0c-6d2d70a0a0da
# ╟─98bfd4d0-9257-4c2e-8256-29833c4b2850
# ╠═cc7e6e63-7630-4500-a18b-92d254089a12
# ╟─38f06b03-50b7-4254-b111-d9b15a39a910
# ╠═b992f24e-ead5-4117-8744-1a81c16f13a7
# ╟─a5bc9651-176f-41ed-8cc9-81c1accfc4db
# ╠═977a2703-17c9-443f-a110-334e38377909
# ╠═26decc7c-a3c2-41a3-8eec-5ed12296918f
# ╠═ac1d5662-e8c9-48a0-a30f-dcf9ca15af15
# ╠═ffa56bac-2f5c-4d1b-8e5a-7d3412393f14
# ╠═dc1fd780-64d8-4113-b19f-9bb0733eed99
# ╠═fedadec6-70a7-483f-9199-877ef60a5861
# ╟─b01206a2-7b5e-4a7a-842b-354ab1ec5b0d
# ╟─fcbff47c-d7ee-471e-b452-2360a142ac29
# ╠═9042910c-802b-4a71-8863-5b64984b3a8c
# ╟─d8c646d9-6c1a-4ca1-8f4a-a22bb1623132
# ╟─c42f8de4-5790-4558-8e98-a16540c78885
# ╟─bd2b9f50-672d-4cf2-806e-93c8b7d71918
# ╠═73c8585e-6d3c-4119-a786-950244ceeeb2
# ╠═6a44f96c-a264-48b9-83f3-bc64a607c730
# ╠═b7715de1-59a9-460c-8c4e-535713f1e317
# ╠═b80f21e4-331c-4677-84d4-77259c2422b4
# ╠═c4f1bc99-f0b2-45eb-afd5-19483de2e8c8
# ╠═725a2620-6e6d-4964-840a-ca318fe871db
# ╠═f866230f-0cbe-4462-a3d7-0ef148a944c9
# ╠═da025bce-a955-4f6a-916c-bac1e1f491dd
# ╠═e6e50f4a-6da4-4b10-9b92-2c7436f57072
# ╠═6056db12-a40c-4586-bb63-203fcd0c0cce
# ╠═9503331e-e97f-4ba9-84aa-c1e11c2f59d1
# ╠═f6d52515-c34a-4159-b4e7-625cba13763c
# ╠═1e6c1d0b-8a3b-4cec-928f-a2e892fdbf5e
# ╠═ea503006-18b6-47a1-8cb3-46d856dfe8b0
# ╠═89f8c950-32bd-49d3-8a62-79e0040646ec
# ╠═fa0c5865-1c22-4a9e-b393-b8f5875ff841
# ╠═15ef23fa-1633-4954-a927-1d289d5573ec
# ╠═d7c66368-4769-4d50-b20f-9ea4ed6eee5a
# ╠═2838b7e5-752b-4cb6-bec5-f48d122e859c
# ╠═c4cb9e33-4362-40f9-baba-ac822cbedc64
# ╟─7e150a69-0070-4371-b5c0-02b7ad70d813
# ╠═16cdbadf-4deb-4a66-8ab7-84437a4fe3d4
# ╟─4a0e30fe-398e-4d80-86a2-bfc384cbc6e6
# ╠═9cc3dfcb-b95d-4086-a228-ed4753f6ca0d
# ╟─591f9fcb-7ad1-400e-af0a-29686a4914ec
# ╠═9cc092e9-40d2-4c5a-9b55-4e2adccb3382
# ╠═d75a8426-c97b-422e-8c69-3f3ce94c5370
# ╟─a7d330cf-5093-490f-adc8-e482e3084806
# ╟─280a17c4-6d5e-4ff3-a5ab-dbbcb7199bb2
# ╟─a230e061-b6ab-49d4-bdad-730d75e20e9c
# ╠═6d5e295c-1c57-4a92-aee2-3ffcbb3306df
# ╠═80447dc7-1103-4019-bc64-283d4a9368a0
# ╠═08ec5b69-946f-407e-ac8d-bf8814cc0121
# ╠═2fdad658-0b71-4d42-8591-9284fee3aeb6
# ╠═5a0cc7d8-a3c3-45b9-8b91-9528e4938fb0
# ╟─58b227ac-627f-49ba-bc58-75039c65733b
# ╠═4223f9f8-8ee6-4ea9-a7bc-6379c81c48c0
# ╟─fabba61a-f28d-4535-b0e3-e94f5098bb0a
# ╟─7a1fcff4-6948-4333-b971-8fbf31c7d3ee
# ╠═a917927d-d471-4465-abd1-30d959af0b45
# ╠═93b78d1a-ee07-4d66-b5a4-c7a109a24f81
# ╟─aa4283d7-37d4-4aaf-a5b7-b515466e545d
# ╟─19b7d7fb-adab-4f29-82af-d059525921ee
# ╠═102a2054-2fd5-406e-8bb4-20ecb47c278f
# ╟─e97474ef-145f-45c8-96f6-213acf4a3b41
# ╟─106f7063-719e-4eff-857d-3566d6e6d4c8
# ╟─177762d5-b9f2-449b-abba-256f3d4318ad
# ╟─4e4ab4e5-bacc-4c58-8000-10602a1f8465
# ╟─e35f8650-dc2e-46f3-9220-26754e8860e0
# ╟─13827ddc-bebd-44d5-929f-f4ac6f43b093
# ╟─2a07dd38-bac4-410c-8135-5c4e6f851df6
# ╟─a3703591-17d4-4049-8c1b-21a4c8329ffd
# ╟─ebe4e491-1c61-45cb-a559-64fa3f5fbb9d
# ╟─d6d6dc94-5b99-4de6-a5c3-ab2be2b49d32
# ╠═b0112287-c957-4ce3-ba24-9c47c8128b2d
# ╟─417fecfd-b316-4e63-8e68-303d4c568434
# ╟─bbd09112-d6cd-4f0f-9a87-7b85be983e09
# ╟─8c405cc2-e8b5-4125-b21d-f7a22f94fb59
# ╟─ebe77978-7d7f-407d-9a73-4be3568265ef
# ╟─e7e7b1ca-b27f-406c-9df0-5ffea702719f
# ╟─f48eb494-f9f5-4e4f-9fc0-ffa20312155a
# ╟─4eeabd93-cd82-4051-b2d0-bee3db1723e4
# ╟─fc5b2f60-2c04-4835-a222-9971189ac54e
# ╟─e40a68c6-5885-49d1-9259-fdd3be09fee4
# ╟─f79fb47b-b4f7-442a-927f-0c186e673b80
# ╠═8da11b18-5934-4207-941b-795969173f21
# ╟─ce47be17-7773-4797-beb7-202d3c02555a
# ╟─498d145b-ce5f-46a5-b77e-31f412e04eb9
# ╟─0d4a0651-4ce4-497e-8764-2bcbbef83cf1
# ╟─d437cc55-8c19-4d0b-86d8-760da3956895
# ╟─7dedd16b-4279-4f50-8120-d9ef394f3e13
# ╟─649fa1b3-0dd2-487d-9bdf-7db97a0ec178
# ╟─92a5b436-1d8e-4436-8dda-8b1d3518bdea
# ╟─c5b0405a-a991-45a5-aa04-d09020b0c7f0
# ╟─8d4516fd-8838-4e5f-a61d-9dc1f65b31ad
# ╟─4a1cf5fc-b44f-4b19-ac8e-d610da0a17cb
# ╟─03e15d19-ea63-413e-8ec5-4d50e28558ac
# ╟─39a7f7b4-058b-4283-b35c-4409ea9e478a
# ╟─52aeae45-0dfc-48f2-a362-20d1add0ff7f
# ╟─abe34c91-9824-45e4-8865-7b3f73ff8758
# ╟─960ba1ef-495d-4bb2-8aff-73cb68ae440e
# ╟─9d97d16a-8f90-4ff7-ac0b-ee610c20ee32
# ╟─8815a3e2-e559-4857-b20e-14aa5f91d341
# ╟─89aa75b3-2263-450e-9f2e-cd7c875a7919
# ╟─b5045344-fb52-4b2e-88b9-1c1d4d1d50f6
# ╟─f6fefa8e-8490-4c0d-b707-c9a95011cbb1
# ╟─3555a982-9879-460f-babf-6f31c11c6f7f
# ╟─954d503d-19f2-4575-84d7-2d1722a28a7f
# ╟─41eb41f7-bc6e-4dce-8d39-68142fd329db
# ╟─bc6ba394-d1b8-4c1b-8a01-c23bcd29178c
# ╟─7140a27e-4cde-4c7d-a794-9a624e540677
# ╠═b0bf01be-6a53-4c42-9d9a-752bf4652986
# ╟─0ee9bd36-7192-4922-abaf-7d7d08605915
# ╠═d5ef9a03-f716-454b-a5de-0c67ee935679
# ╠═df1ff4c2-8c84-455a-9cc4-7fdc34e2cb83
# ╠═6396d4af-e668-4a73-b8be-b73b8b41267c
# ╠═f38318dd-f7bb-4bf1-9bc9-d1f7ed8a8397
# ╠═356b7b35-6794-40d0-8c88-b8e066f086a6
# ╠═6445e2c6-4dcc-44dd-bdda-564e4c9b3911
# ╠═7e0b0616-5dd0-44d3-beab-4fa32521d3ff
# ╠═b49c15a7-d9de-4942-b09c-7f2ed9b4550e
# ╠═f615fc39-bfd9-45ce-84fe-a28921bde525
# ╠═d49e7e9b-6487-407b-aef7-2884461879a0
# ╠═43e8a5f1-512c-46b7-91f6-89d3c7e81368
# ╟─ae5f17d2-3c31-4a9c-85e4-f2f22625d86b
# ╠═c3952378-79bb-4605-8ffb-828c1e3e3321
# ╟─0f7ff8a4-43e4-4829-a4b4-78594664cee2
# ╟─131f4e45-85f5-43bc-8c32-d59f8803bfd6
# ╠═a4066207-4c50-4360-b43f-218d5355ff3e
# ╟─218fc76e-1060-40ff-a52f-d884441380e2
# ╟─58b61eac-e1de-48f3-a37b-ecc1f8d5f8ab
# ╠═320f9c75-5047-4a4c-890b-ffdc70767634
# ╠═b97cd0a9-ee46-4520-a408-f60150bbea74
# ╠═b96961fd-6a9a-40bb-b582-2b3586f56edb
# ╠═eba3554f-ae6f-4a3d-8131-43ffa2743977
# ╠═f57ca807-9b3a-4f77-9607-74ee3a411990
# ╠═7a6a3b8a-8b1c-41d5-ab25-7d294f1bee3d
# ╠═92698c05-edf3-4b9e-a10a-1da9ed0dc82a
# ╠═0dd448d1-9952-438c-9284-e0c320c955aa
# ╠═f8b61a8e-2679-48cd-842c-17d6e6ee760e
# ╠═bfc6e346-3525-47d7-a436-ffa02dab11b9
# ╠═2ff6f551-2662-43a5-9776-70951ff40364
# ╠═ec3cd40c-6a52-48fd-a3ce-9e091250e981
# ╠═525b0316-8374-4882-aa5b-84f2bf33c5c3
# ╠═840fa50e-bf0f-42f9-8e7f-ec3cc4bdb9af
# ╠═5738e27c-5307-4623-bd43-67f66b7b97d2
# ╠═14360d77-340e-488d-bed0-00f408ef1dd4
# ╠═685fd840-64b1-427d-83f3-217664ea9798
# ╠═8ecc8206-275b-4d55-9b01-e82e7f2df5dc
# ╠═aac7a640-97fe-46c0-89b3-7e76978baf0d
# ╠═89ef5f08-7a1e-42a5-8fcf-b7efa63a8a68
# ╠═f1e6c6b6-49fa-44bb-bb9a-07986f6a1d13
# ╠═426f8190-7865-4bd1-bc23-0adb5fc1892c
# ╠═c54205d5-ea1a-4416-b4b0-3bdb168dae61
# ╠═b83d4ff4-cc73-4cf7-abad-78da291eb404
# ╠═13ad7221-0d2d-4a77-9258-9edace85fde0
# ╠═f2b2cc4d-54ed-4f2f-80bc-bc3bf82bb2e8
# ╟─00000000-0000-0000-0000-000000000001
# ╟─00000000-0000-0000-0000-000000000002
