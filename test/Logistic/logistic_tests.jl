using Test
using LogicCircuits
using ProbabilisticCircuits
using DiscriminativeCircuits
using DataFrames: DataFrame
using CUDA

# This tests are supposed to test queries on the circuits
@testset "Logistic Circuit Query and Parameter Tests" begin
    # Uses a Logistic Circuit with 4 variables, and tests 3 of the configurations to 
    # match with python version.
    
    CLASSES = 2

    logistic_circuit = zoo_dc("little_4var.circuit")
    @test logistic_circuit isa LogisticCircuit

    # check probabilities for binary samples
    data_raw = @. Bool([0 0 0 0; 0 1 1 0; 0 0 1 1])
    data = DataFrame(data_raw, :auto)
    # true_weight_func = [3.43147972 4.66740416; 
    #                     4.27595352 2.83503504;
    #                     3.67415087 4.93793472]
    true_prob = [0.9686740008311808 0.9906908445371728;
                 0.9862917392724188 0.9445399509069984; 
                 0.9752568185086389 0.9928816444223209]
            
    class_prob = class_likelihood_per_instance(logistic_circuit, data)
    for i = 1:size(true_prob)[1]
        for j = 1:CLASSES
            @test true_prob[i,j] ≈ class_prob[i,j]
        end
    end

    # check probabilities for float samples
    data = DataFrame(Float32.(data_raw), :auto)
    class_prob = class_likelihood_per_instance(logistic_circuit, data)
    for i = 1:size(true_prob)[1]
        for j = 1:CLASSES
            @test true_prob[i,j] ≈ class_prob[i,j]
        end
    end

    # check predicted_classes
    true_labels = [2, 1, 2]
    predicted_classes = predict_class(logistic_circuit, data)
    @test all(predicted_classes .== true_labels)
    
    # check accuracy
    @test accuracy(logistic_circuit, data, true_labels) == 1.0

    # check parameter updates
    original_literal_parameters = Dict{Int, Vector{Float64}}()
    foreach(logistic_circuit) do ln
        if ln isa Logistic⋁Node
            foreach(ln.children, eachrow(ln.thetas)) do c, theta
                if c isa LogisticLiteralNode
                    original_literal_parameters[c.literal] = copy(theta)
                end
            end
        end
    end
    
    one_hot_labels = [0.0 1.0;
                      1.0 0.0;
                      0.0 1.0]
    one_hot_labels = Float32.(one_hot_labels)
    true_error = true_prob .- one_hot_labels
    step_size = 0.1
    learn_parameters(logistic_circuit, data, true_labels; num_epochs=1, step_size=step_size)

    if CUDA.functional()
        data_gpu = to_gpu(data)
        labels_gpu = to_gpu(true_labels)
        learn_parameters(logistic_circuit, data_gpu, labels_gpu; num_epochs=1, step_size=step_size)
    end

    #####
    ### TODO; not valid code anymore `c.data`, not exactly sure what this was doing but seems was when we had upflow circuits
    ####
    # foreach(logistic_circuit) do ln
    #     if ln isa Logistic⋁Node
    #         foreach(ln.children, eachrow(ln.thetas)) do c, theta
    #             if c isa LogisticLiteralNode
    #                 for class = 1:CLASSES
    #                     true_update_amount = -step_size * sum(c.data.upflow .* true_error[:, class]) / size(true_error)[1]
    #                     updated_amount = theta[class] - original_literal_parameters[c.literal][class]
    #                     @test updated_amount ≈ true_update_amount atol=1e-7
    #                 end
    #             end
    #         end
    #     end
    # end

end