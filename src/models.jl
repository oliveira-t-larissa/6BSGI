using JuMP, Gurobi

###############################################################################
############################ Funcoes auxiliares ###############################
###############################################################################
poly(a::Vector,x::Float64) = sum(a[i]*x^(i-1) for i in eachindex(a)) 

function aprox2_poly(a,xmin,xmax)
	x = (xmin+xmax)/2;
	num_a = length(a)
	if num_a < 5
	a = vcat(a, zeros(5-num_a))
	end
	b = Float64[]
	push!(b, 3*a[5]*x^4 + a[4]*x^3 + a[1])
	push!(b, -8*a[5]*x^3 -3*a[4]*x^2 + a[2])
	push!(b, 6*a[5]*x^2 + 3*a[4]*x + a[3])
return b
end

function interp2_poly(a,xmin,xmax)
	x = (xmin+xmax)/2;
	num_a = length(a)
	if num_a < 5
	a = vcat(a, zeros(5-num_a))
	end
#	b = Float64[]
	b0 = a[1] + (3*a[5]*xmin^3*xmax)/4 + (3*a[5]*xmin^2*xmax^2)/2 + (a[4]*xmin^2*xmax)/2 + (3*a[5]*xmin*xmax^3)/4 + (a[4]*xmin*xmax^2)/2;
	b1 = a[2] - (a[4]*xmin^2)/2 - (a[4]*xmax^2)/2 - (3*a[5]*xmin^3)/4 - (3*a[5]*xmax^3)/4 - (13*a[5]*xmin*xmax^2)/4 - (13*a[5]*xmin^2*xmax)/4 - 2*a[4]*xmin*xmax;
	b2 = a[3] + (7*a[5]*xmin^2)/4 + (5*a[5]*xmin*xmax)/2 + (3*a[4]*xmin)/2 + (7*a[5]*xmax^2)/4 + (3*a[4]*xmax)/2;
return [b0, b1, b2]
end

function pgg_lin(pg,f,xmin,xmax)

    x0 = (xmin+xmax)/2;
    c0 = pgg_func(f,x0);
    c1 = f[2]*pgg_func(f,x0);
    c0 = c0 - c1*x0;    
    #y = c0+c1*pg;
 return [c0, c1]
end

pmt_func(pg,g) =  poly(g,pg) #quadratica
pgg_func(pg,f) = f[1]*exp(f[2]*pg)
h(a,b,k_p,k_pusina,k_s,q,V,s) = poly(a,V) - poly(b,Q+s) + k_p*q^2 + K_pusina*Q^2 + k_s*q^2
#rho_func(c,q,h) = c[1] + c[2]*q +c[3]*h + c[4]*h*q + c[5]*q^2+ c[6]*h^2 
#pst_func(G,c,rho,h,q) = G*( c[1]*h*q + c[2]*h*q^2 +c[3]*h^2*q + c[4]*h^2*q^2 + c[5]*h*q^3+ c[6]*h^3*q )
#pst_func(G,c,rho,h,q) = G*( c[1]*h*q + c[2]*h*q^2 +c[3]*h^2*q + c[4]*h^2*q^2 + c[5]*h*q*q^2+ c[6]*h^2*h*q )
pst_func(G,c,h,h2,q,q2,hq) = G*( c[1]*h*q + c[2]*h*q2 +c[3]*h2*q + c[4]*h2*q2 + c[5]*hq*q2+ c[6]*h2*hq )




function create_model(model::Model)
    T = 24
    R = 4 
    J = [3 3 3 5]		# numero de unidades (turbinas) para cada usina (reservatorio)	
    L = rand(R,T)		# numero de retas aproximando a funcao alpha (custo da agua) para cada reservatorio
    max_J =maximum(J)
    preco_hora = 500*rand(T)				# valor da energia por hora do dia
    v0 = [2500 1000 500 1000]
    c1 = 0.8
    y = rand(R,T)
    R_up = [[], [], [1,2], [3]]
    tau = [ 1 1 1 1
        1 1 1 1
        1 1 1 1
        1 1 1 1]
        vmin = 10*ones(R)
        vmax = 5000*ones(R)
        alpha_demanda = 0.5
        q_min = rand(max_J,R,T)
        q_max = 1000*rand(max_J,R,T)
        pmin = rand(max_J,R,T)
        
        pmax = 1000*rand(max_J,R,T)
        a = [243 1.07 -0.011]
        pg_rampa = 0.8*ones(max_J,R)
        fcm_max = 100*rand(R)
        delta_fcm = 0.8*ones(R)

    d = interp2_poly(cotaMontante,vmin,vmax)   
    e = interp2_poly(contaJusante,qsmin,qsmax)
    k_pusina = 0
        ###############################################################################
        ############################ Variáveis ########################################
        ###############################################################################
        @variable(model, 0<= v[r=1:R, t=1:T])			# volume armazenado no reservatorio R no tempo t
        @variable(model, 0<= s[r=1:R, t=1:T])			# volume vertido no reservatorio R no tempo t
        @variable(model, 0<= Q[r=1:R, t=1:T])			# vazao turbinada no reservatorio R no tempo t
        @variable(model, 0<= q[j=1:max_J, r=1:R, t=1:T])		# vazao turbinada pela unidade j do reservatorio R no tempo t
        @variable(model, 0<= h[j=1:max_J, r=1:R, t=1:T])		# vazao turbinada pela  
        @variable(model, 0<= q2[j=1:max_J, r=1:R, t=1:T])		# vazao turbinada pela
        @variable(model, 0<= h2[j=1:max_J, r=1:R, t=1:T])		# vazao turbinada pela
        @variable(model, 0<= hq[j=1:max_J, r=1:R, t=1:T])		# vazao turbinada pela
        @variable(model, 0<= pg[j=1:max_J, r=1:R, t=1:T])		#u_jrt = 1 se a unidade j do reservatorio r no tempo T está ligado
        @variable(model, 0<= pmt[j=1:max_J, r=1:R, t=1:T])		#u_jrt = 1 se a unidade j
        @variable(model, 0<= pgg[j=1:max_J, r=1:R, t=1:T])		#u_jrt = 1 se a unidade j
        @variable(model, 0<= pst[j=1:max_J, r=1:R, t=1:T])		#u_jrt = 1 se a unidade j
        
        ###############################################################################
        ############################ Objective function################################
        ###############################################################################
    
        @objective(model, Max, sum(preco_hora[t]*pg[j,r,t] for r=1:R, t=1:T, j=1:J[r])) 
        
        ###############################################################################
        ############################ Restricoes #######################################
        ###############################################################################
        @constraint(model, [r=1:R, t=1], v[r,t] - v0[r] + c1*(Q[r,t]+s[r,t]) == c1*y[r,t] )
        @constraint(model, [r=1:R, t=2:T], v[r,t] - v[r, t-1] + c1*(Q[r,t]+s[r,t] - sum(Q[m,t-tau[m,r]]+s[m,t-tau[m,r]] for m in R_up[r] if (t-tau[m,r])>=1)) == c1*y[r,t] )
        @constraint(model, [r=1:R, t=1:T], vmin[r] <= v[r,t])
        @constraint(model, [r=1:R, t=1:T], vmax[r] >= v[r,t])
        @constraint(model, [r=1:R, t=1:T], sum(pg[j,r,t] for j=1:J[r]) >= alpha_demanda*L[r,t])
        @constraint(model,[r=1:R, t=1:T, j=1:J[r]],pst[j,r,t] == pst_func(G,RendHidro[j,r],h[j,r,t],h2[j,r,t],q[j,r,t],q2[j,r,t],hq[j,r,t]))
        @NLconstraint(model,[r=1:R, t=1:T, j=1:J[r]], pmt[j,r,t] == pmt_func(pg[j,r,t],PerdaMecTurb[j,r]))
        c = pgg_lin(pg,f[j,r],xmin[j,r],xmax[j,r])    
        @constraint(model, [r=1:R, t=1:T, j=1:J[r]], pgg[j,r,t]  == c[1]+c[2]*pg[j,r,t] )
        @constraint(model, [r=1:R, t=1:T, j=1:J[r]], pg[j,r,t] - pst[j,r,t] + pmt[j,r,t] + pgg[j,r,t]  ==0)
            
        @constraint(model, [r=1:R, t=1:T, j=1:J[r]], h[j,r,t] == d[0] +d[1]*v[r,t] +d[2]*v[r,t]^2 -(e[0] +e[1]*(Q[r,t]-s[r,t]) +e[2]*(Q[r,t]-s[r,t])^2) - (k_p*q[j,r,t]^2 + k_pusina*Q[r,t]^2) - k_s*q[j,r,t]^2 )
        
        @constraint(model, [r=1:R, t=1:T], sum(q[j,r,t] for j=1:J[r])-Q[r,t]==0)
        @constraint(model, [r=1:R, t=1:T, j=1:J[r]], q_min[j,r,t] <= q[j,r,t])
        @constraint(model, [r=1:R, t=1:T, j=1:J[r]], q_max[j,r,t] >= q[j,r,t])
        @constraint(model, [r=1:R, t=1:T, j=1:J[r]], pmin[j,r,t] <= pg[j,r,t])
        @constraint(model, [r=1:R, t=1:T, j=1:J[r]], pmax[j,r,t] >= pg[j,r,t])
        
    # @constraint(model, [r=1:R, t=1:T, j=1:J[r]], pg_min[r,j,t]*z[j,k,r,t] <= pg[j,r,t])
    # @constraint(model, [r=1:R, t=1:T, j=1:J[r],k=1:K], pg_max[r,j,t]*z[j,r,k,t] >= pg[j,r,t])
        
        ###############################################################################
        ############################ FCM ao final do dia ##############################
        ############################ fcm = a0+ a1*v+a2v^2 #############################
        ###############################################################################
        @constraint(model, [r=1:R, t=T], a[1] + a[2]*v[r,t] + a[3]*v[r,t]^2 >= fcm_max[r]*delta_fcm[r])	
    # @constraint(model, [r=1:T, t=T, l=1:L[r]], alpha[r] >= coef[r,l,1] + coef[r,l,2]*v[r,t])
        
        
        ###############################################################################
        ######################### Rampas para  das turbinas ####################
        ###############################################################################
        @constraint(model, [r=1:R, t=1:T-1, j=1:J[r]], pg[j,r,t]-pg[j,r,t+1] <= pg_rampa[j,r]*pg[j,r,t])    
        @constraint(model, [r=1:R, t=1:T-1, j=1:J[r]], pg[j,r,t+1]-pg[j,r,t] <= pg_rampa[j,r]*pg[j,r,t])
        
        ###############################################################################
        ######################### ativacao/destivacao das turbinas ####################
        ###############################################################################
    # @constraint(model, [r=1:R, t=1, j=1:J[r]], u_on[j,r,t] >= u[j,r,t] - u_begin[j,r])
    # @constraint(model, [r=1:R, t=1, j=1:J[r]], u_off[j,r,t] >= u_begin[j,r] - u[j,r,t])
    # @constraint(model, [r=1:R, t=2:T, j=1:J[r]], u_on[j,r,t] >= u[j,r,t] - u[j,r,t-1])
    # @constraint(model, [r=1:R, t=2:T, j=1:J[r]], u_off[j,r,t] >= u[j,r,t-1] - u[j,r,t])
    # @constraint(model, [r=1:R, t=1:T-delta_tempo, j=1:J[r]], delta_tempo*u_off[r,j,t] <= delta_tempo -sum(u[r,j,t+delta_tempo]))
    # @constraint(model, sum(u_on[j,r,t]+u_off[j,r,t] for r=1:R, t=1, j=1:J[r]) <= max_epsilon)
        
        ###############################################################################


        ###############################################################################
        ############## restricoes se usar as curvas colina ############################
        ###############################################################################
        #@constraint(model, [r=1:R, t=1:T, j=1:J[r]], pg_min[r,j,t]*z[j,r,t] <= pg[j,r,t])
        #@constraint(model, [r=1:R, t=1:T, j=1:J[r]], pg_max[r,j,t]*z[j,r,t] >= pg[j,r,t])
        #@constraint(model, [r=1:R, t=1:T, j=1:J[r]], z[r,j,t] == u[j,r,t])
        #@constraint(model, [r=1:R, t=1:T, j=1:J[r]], z[r,j,t] <= u[j,r,t])
end


function create_model(model::Model,data::Dict; T=24)
    R = 4 
    J = [3 3 3 5]		# numero de unidades (turbinas) para cada usina (reservatorio)	
    L = rand(R,T)		# numero de retas aproximando a funcao alpha (custo da agua) para cada reservatorio
    max_J =maximum(J)
    preco_hora = 500*rand(T)				# valor da energia por hora do dia
    v0 = [2500 1000 500 1000]
    c1 = 0.8
    y = rand(R,T)
    R_up = [[], [], [1,2], [3]]
    tau = [ 1 1 1 1
        1 1 1 1
        1 1 1 1
        1 1 1 1]
        vmin = 10*ones(R)
        vmax = 5000*ones(R)
        alpha_demanda = 0.5
        q_min = rand(max_J,R,T)
        q_max = 1000*rand(max_J,R,T)
        pmin = rand(max_J,R,T)
        
        pmax = 1000*rand(max_J,R,T)
        a = [243 1.07 -0.011]
        pg_rampa = 0.8*ones(max_J,R)
        fcm_max = 100*rand(R)
        delta_fcm = 0.8*ones(R)

    d = interp2_poly(cotaMontante,vmin,vmax)   
    e = interp2_poly(contaJusante,qsmin,qsmax)
    k_pusina = 0
    ###############################################################################
    ############################ Variáveis ########################################
    ###############################################################################
        
    @variable(model, 0<= v[r in keys(data), t in 1:T])			# volume armazenado no reservatorio R no tempo t
    @variable(model, 0<= s[r in keys(data), t in 1:T])			# volume vertido no reservatorio R no tempo t
    @variable(model, 0<= Q[r in keys(data), t in 1:T])			# vazao turbinada no reservatorio R no tempo t
    @variable(model,0<= q[r in keys(data), t in 1:T,j in 1: data[r]["nUG"]]) # vazao turbinada pela unidade j do reservatorio R no tempo t
    @variable(model, 0<= q[r in keys(data), t in 1:T,j in 1: data[r]["nUG"]])		
    @variable(model, 0<= h[r in keys(data), t in 1:T,j in 1: data[r]["nUG"]])		# vazao turbinada pela  
    @variable(model, 0<= q2[r in keys(data), t in 1:T,j in 1: data[r]["nUG"]])		# vazao turbinada pela
    @variable(model, 0<= h2[r in keys(data), t in 1:T,j in 1: data[r]["nUG"]])		# vazao turbinada pela
    @variable(model, 0<= hq[r in keys(data), t in 1:T,j in 1: data[r]["nUG"]])		# vazao turbinada pela
    @variable(model, 0<= pg[r in keys(data), t in 1:T,j in 1: data[r]["nUG"]])		#u_jrt = 1 se a unidade j do reservatorio r no tempo T está ligado
    @variable(model, 0<= pmt[r in keys(data), t in 1:T,j in 1: data[r]["nUG"]])		#u_jrt = 1 se a unidade j
    @variable(model, 0<= pgg[r in keys(data), t in 1:T,j in 1: data[r]["nUG"]])		#u_jrt = 1 se a unidade j
    @variable(model, 0<= pst[r in keys(data), t in 1:T,j in 1: data[r]["nUG"]])		#u_jrt = 1 se a unidade j
        
    ###############################################################################
    ############################ Objective function################################
    ###############################################################################
    
        @objective(model, Max, sum(preco_hora[t]*pg[r,t,j] for r in keys(data), t in 1:T,j in 1: data[r]["nUG"])) 
        
        ###############################################################################
        ############################ Restricoes #######################################
        ###############################################################################
        @constraint(model, [r=1:R, t=1], v[r,t] - v0[r] + c1*(Q[r,t]+s[r,t]) == c1*y[r,t] )
        @constraint(model, [r=1:R, t=2:T], v[r,t] - v[r, t-1] + c1*(Q[r,t]+s[r,t] - sum(Q[m,t-tau[m,r]]+s[m,t-tau[m,r]] for m in R_up[r] if (t-tau[m,r])>=1)) == c1*y[r,t] )
        @constraint(model, [r=1:R, t=1:T], vmin[r] <= v[r,t])
        @constraint(model, [r=1:R, t=1:T], vmax[r] >= v[r,t])
        @constraint(model, [r=1:R, t=1:T], sum(pg[j,r,t] for j=1:J[r]) >= alpha_demanda*L[r,t])
        @constraint(model,[r=1:R, t=1:T, j=1:J[r]],pst[j,r,t] == pst_func(G,RendHidro[j,r],h[j,r,t],h2[j,r,t],q[j,r,t],q2[j,r,t],hq[j,r,t]))
        @NLconstraint(model,[r=1:R, t=1:T, j=1:J[r]], pmt[j,r,t] == pmt_func(pg[j,r,t],PerdaMecTurb[j,r]))
        c = pgg_lin(pg,f[j,r],xmin[j,r],xmax[j,r])    
        @constraint(model, [r=1:R, t=1:T, j=1:J[r]], pgg[j,r,t]  == c[1]+c[2]*pg[j,r,t] )
        @constraint(model, [r=1:R, t=1:T, j=1:J[r]], pg[j,r,t] - pst[j,r,t] + pmt[j,r,t] + pgg[j,r,t]  ==0)
            
        @constraint(model, [r=1:R, t=1:T, j=1:J[r]], h[j,r,t] == d[0] +d[1]*v[r,t] +d[2]*v[r,t]^2 -(e[0] +e[1]*(Q[r,t]-s[r,t]) +e[2]*(Q[r,t]-s[r,t])^2) - (k_p*q[j,r,t]^2 + k_pusina*Q[r,t]^2) - k_s*q[j,r,t]^2 )
        
        @constraint(model, [r=1:R, t=1:T], sum(q[j,r,t] for j=1:J[r])-Q[r,t]==0)
        @constraint(model, [r=1:R, t=1:T, j=1:J[r]], q_min[j,r,t] <= q[j,r,t])
        @constraint(model, [r=1:R, t=1:T, j=1:J[r]], q_max[j,r,t] >= q[j,r,t])
        @constraint(model, [r=1:R, t=1:T, j=1:J[r]], pmin[j,r,t] <= pg[j,r,t])
        @constraint(model, [r=1:R, t=1:T, j=1:J[r]], pmax[j,r,t] >= pg[j,r,t])
        
    # @constraint(model, [r=1:R, t=1:T, j=1:J[r]], pg_min[r,j,t]*z[j,k,r,t] <= pg[j,r,t])
    # @constraint(model, [r=1:R, t=1:T, j=1:J[r],k=1:K], pg_max[r,j,t]*z[j,r,k,t] >= pg[j,r,t])
        
        ###############################################################################
        ############################ FCM ao final do dia ##############################
        ############################ fcm = a0+ a1*v+a2v^2 #############################
        ###############################################################################
        @constraint(model, [r=1:R, t=T], a[1] + a[2]*v[r,t] + a[3]*v[r,t]^2 >= fcm_max[r]*delta_fcm[r])	
    # @constraint(model, [r=1:T, t=T, l=1:L[r]], alpha[r] >= coef[r,l,1] + coef[r,l,2]*v[r,t])
        
        
        ###############################################################################
        ######################### Rampas para  das turbinas ####################
        ###############################################################################
        @constraint(model, [r=1:R, t=1:T-1, j=1:J[r]], pg[j,r,t]-pg[j,r,t+1] <= pg_rampa[j,r]*pg[j,r,t])    
        @constraint(model, [r=1:R, t=1:T-1, j=1:J[r]], pg[j,r,t+1]-pg[j,r,t] <= pg_rampa[j,r]*pg[j,r,t])
        
        ###############################################################################
        ######################### ativacao/destivacao das turbinas ####################
        ###############################################################################
    # @constraint(model, [r=1:R, t=1, j=1:J[r]], u_on[j,r,t] >= u[j,r,t] - u_begin[j,r])
    # @constraint(model, [r=1:R, t=1, j=1:J[r]], u_off[j,r,t] >= u_begin[j,r] - u[j,r,t])
    # @constraint(model, [r=1:R, t=2:T, j=1:J[r]], u_on[j,r,t] >= u[j,r,t] - u[j,r,t-1])
    # @constraint(model, [r=1:R, t=2:T, j=1:J[r]], u_off[j,r,t] >= u[j,r,t-1] - u[j,r,t])
    # @constraint(model, [r=1:R, t=1:T-delta_tempo, j=1:J[r]], delta_tempo*u_off[r,j,t] <= delta_tempo -sum(u[r,j,t+delta_tempo]))
    # @constraint(model, sum(u_on[j,r,t]+u_off[j,r,t] for r=1:R, t=1, j=1:J[r]) <= max_epsilon)
        
        ###############################################################################


        ###############################################################################
        ############## restricoes se usar as curvas colina ############################
        ###############################################################################
        #@constraint(model, [r=1:R, t=1:T, j=1:J[r]], pg_min[r,j,t]*z[j,r,t] <= pg[j,r,t])
        #@constraint(model, [r=1:R, t=1:T, j=1:J[r]], pg_max[r,j,t]*z[j,r,t] >= pg[j,r,t])
        #@constraint(model, [r=1:R, t=1:T, j=1:J[r]], z[r,j,t] == u[j,r,t])
        #@constraint(model, [r=1:R, t=1:T, j=1:J[r]], z[r,j,t] <= u[j,r,t])
        return model
end
