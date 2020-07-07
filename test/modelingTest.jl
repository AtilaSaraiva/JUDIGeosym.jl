# Test 2D modeling
# The receiver positions and the source wavelets are the same for each of the four experiments.
# Author: Philipp Witte, pwitte@eos.ubc.ca
# Date: January 2017
#
# Mathias Louboutin, mlouboutin3@gatech.edu
# Updated July 2020

using Distributed, JOLI

parsed_args = parse_commandline()

# Set parallel if specified
nw = parsed_args["parallel"]
if nw > 1 && nworkers() < nw
    addprocs(nw-nworkers() + 1; exeflags=`--check-bounds=yes`)
end

@everywhere using JOLI
@everywhere using JUDI.TimeModeling, LinearAlgebra, Test, Distributed, Printf

### Model
model, model0, dm = setup_model(parsed_args["tti"], parsed_args["nlayer"]; n=(101, 101), d=(10., 10.))
q, srcGeometry, recGeometry, info = setup_geom(model; nsrc=2, tn=500f0)
dt = srcGeometry.dt[1]

# Modeling operators
println("Generic modeling and misc test with ", parsed_args["nlayer"], " layers and tti: ", parsed_args["tti"])

######################## WITH DENSITY ############################################
@everywhere function to_data(judiVec)
    try
        return get_data(judiVec)
    catch e
        return judiVec
    end
end

for limit_m=[true, false]
	for disk=[true, false]
		println("Generic tests with limit_m = ", limit_m, " and save to disk = ", disk)
		# Options structures
		opt = Options(save_data_to_disk=disk, limit_m=limit_m, buffer_size=100f0,
					  file_path=pwd(),	# path to files
					  file_name="shot_record")	# saves files as file_name_xsrc_ysrc.segy

		opt0 = Options(save_data_to_disk=disk, limit_m=limit_m, buffer_size=100f0,
					   file_path=pwd(),	# path to files
					   file_name="smooth_shot_record")	# saves files as file_name_xsrc_ysrc.segy

		optJ = Options(save_data_to_disk=disk, limit_m=limit_m, buffer_size=100f0,
					   file_path=pwd(),	# path to files
					   file_name="linearized_shot_record")	# saves files as file_name_xsrc_ysrc.segy

		# Setup operators
		Pr = judiProjection(info, recGeometry)
		F = judiModeling(info, model; options=opt)
		F0 = judiModeling(info, model0; options=opt0)
		Ps = judiProjection(info, srcGeometry)

		# Combined operator Pr*F*adjoint(Ps)
		Ffull = judiModeling(info, model, srcGeometry, recGeometry)
		J = judiJacobian(Pr*F0*adjoint(Ps),q; options=optJ) # equivalent to J = judiJacobian(Ffull,q)

		# Nonlinear modeling
		d1 = Pr*F*adjoint(Ps)*q	# equivalent to d = Ffull*q
		dfull = Ffull*q
		@test isapprox(to_data(d1), dfull)

		qad = Ps*adjoint(F)*adjoint(Pr)*d1
		qfull = adjoint(Ffull)*d1
		@test isapprox(qad, qfull)

		# fwi objective function
		f, g = fwi_objective(model0, q, d1; options=opt)
		f, g = fwi_objective(model0, subsample(q,1), subsample(d1,1); options=opt)

		# Subsampling
		for inds=[2, [1, 2]]
		    dsub = subsample(dfull, inds)
		    qsub = subsample(q, inds)
	            Fsub = subsample(F, inds)
		    Jsub = subsample(J, inds)
		    Ffullsub = subsample(Ffull, inds)
		    Pssub = subsample(Ps, inds)
		    Prsub = subsample(Pr, inds)
		    ds1 = Ffullsub*qsub 
		    ds2 = Prsub * Fsub * adjoint(Pssub) *qsub 
		    @test isapprox(ds1, to_data(ds2))
		    @test isapprox(ds1, dsub)
		    @test isapprox(to_data(ds2), dsub)
		end

		# vcat, norms, dot
		dcat = [d1, d1]
		@test isapprox(norm(d1)^2, .5f0*norm(dcat)^2)
		@test isapprox(dot(d1, d1), norm(d1)^2)
	end
end


############################# Full wavefield ############################################
F = judiModeling(info,model)
Ps = judiProjection(info, srcGeometry)
Pr = judiProjection(info, recGeometry)

# Return wavefields
u = F*adjoint(Ps)*q
dobs = Pr*F*adjoint(Ps)*q
v = adjoint(F)*(adjoint(Pr)*dobs)

# Wavefields as source + return wavefields
u2 = F*u
v2 = adjoint(F)*v

a = dot(u2.data, v.data)
b = dot(v2.data, u.data)
@printf(" <F x, y> : %2.5e, <x, F' y> : %2.5e, relative error : %2.5e \n", a, b, a/b - 1)
# Fix why is u2 zero
#@test isapprox(a, b, rtol=1f-4)

