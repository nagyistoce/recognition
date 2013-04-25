function [accuracy, res_one_inc, res_two_inc] = test_stage(test_set_path, rfld_projected, pca_matrix1, rfld_matrix, class_label, class_num, rfld_num)
%% TEST STAGE is the training stage of facial recognition system
%test_set_path      ---the path of the test set directory
%ratio      ---used in partition
%class_label      ---the label of each feature after FLD
%pca_matrix1      ---PCA projected matrix befor FLD
%fld_matrix      ---FLD projected matrix
%pca_matrix2      ---PCA projected matrix after KNN
%rfld_matrix      ---RFLD projected matrix
%facial_feature      ---global feature after RFLD
%fld_projected      ---local feature after FLD
%accuracy       ---the accuracy of this system


%% get all test images
test_file_name = dir([test_set_path, '\*.tiff']);
test_file_num = length(test_file_name);
train_file_num = length(class_label);

% for each test image get its minimum distance and minimum indice of train
% test
min_dis = zeros(test_file_num, 1, 'double');
min_idx = zeros(test_file_num, 1, 'uint8');

% gabor filter mask
gabor_mask = GenGaborFilter;

% weight matrice
weight_mat = [
    0 1 1 1 1 0;
    2 2 1 1 2 2;
    2 4 4 4 4 2;
    0 1 0 0 1 0;
    1 1 2 2 1 1;
    1 2 4 4 2 1;
    0 1 2 2 1 0
    ];

% process each test image
for test_file_idx = 1 : test_file_num
    test_file = imread([test_set_path, '\', test_file_name(test_file_idx).name]);
    fprintf('Loading test image: %s... \n', test_file_name(test_file_idx).name);
    [height, width] = size(test_file);
    
    % preprocess and partition
    [local_blocks, lbw, lbh, block_num] = PreprocessPartition(test_file, width, height);
    
    % Gabor filter
    gabor_filter_result = zeros(lbh, lbw, 24, block_num);
    for local_block_idx = 1 : block_num
        gabor_filter_result(:, :, :, local_block_idx) = GaborFilter(local_blocks(:, :, local_block_idx), gabor_mask);
    end
    
    local_gabor_features = zeros(lbw * lbh * 8, 3 * 42);
    block_idx = 1;
    for local_block_idx = 1 : block_num
        gabor_res_scale1 = gabor_filter_result(:, :, 1 : 8, local_block_idx);
        local_gabor_features(:, block_idx) = reshape(gabor_res_scale1, lbw * lbh * 8, 1);
        block_idx = block_idx + 1;
        gabor_res_scale2 = gabor_filter_result(:, :, 9 : 16, local_block_idx);
        local_gabor_features(:, block_idx) = reshape(gabor_res_scale2, lbw * lbh * 8, 1);
        block_idx = block_idx + 1;
        gabor_res_scale3 = gabor_filter_result(:, :, 17 : 24, local_block_idx);
        local_gabor_features(:, block_idx) = reshape(gabor_res_scale3, lbw * lbh * 8, 1);
        block_idx = block_idx + 1;
    end
    
    % apply PCA to the local gabor features
    local_features = local_gabor_features';
    pca1_projected_local_features = zeros(3 * block_num, train_file_num - class_num);
    for local_block_idx = 1 : block_num * 3
        pca1_projected_local_features(local_block_idx, :) = local_features(local_block_idx, :) * pca_matrix1(:, :, local_block_idx);
    end
    
    % apply RFLD to project feature matrices on to a discriminating,
    % low-dimensional subspace.
    rfld_projected_local_features = zeros(3 * block_num, rfld_num);
    for local_block_idx = 1 : block_num * 3
        rfld_projected_local_features(local_block_idx, :) = pca1_projected_local_features(local_block_idx, :) * rfld_matrix(:, :, local_block_idx);
        rfld_projected_local_features(local_block_idx, :) = mapstd(rfld_projected_local_features(local_block_idx, :));
    end

    % local classifier k-nearest neighbor(KNN) with k = 1. Th ouput of KNN
    % is C-Dimensional vector as estimated probabilities of the C classes.
    % see formula (4)
    train_vec_num = size(rfld_projected, 1);
    
    nearest_block = zeros(train_vec_num, 1);
    nearest_class = zeros(class_num, 1);
    for local_block_idx = 1 : block_num * 3
        temp_projected = rfld_projected(:, :, local_block_idx);
        dist_all = zeros(train_vec_num, 1);
        for train_vec_idx = 1 : train_vec_num
            distance = norm(rfld_projected_local_features(local_block_idx, :) - temp_projected(train_vec_idx, :));
            dist_all(train_vec_idx) = distance;
        end
        [~, index] = sort(dist_all);
        nearest_block(index(1)) = nearest_block(index(1)) + 1.1;
        nearest_block(index(2)) = nearest_block(index(2)) + 1;
        nearest_block(index(3)) = nearest_block(index(3)) + 1;
        
        real_block_num = mod(local_block_idx, block_num);
        if (real_block_num == 0)
            real_block_num = block_num;
        end
        %real_block_num
        real_x = floor((real_block_num - 1) / 6) + 1;
        real_y = mod(real_block_num, 6);
        if (real_y == 0)
            real_y = 6;
        end
        
        weight_num = 5;
        for nearest_idx = 1 : weight_num
            nearest_class(class_label(index(nearest_idx))) = nearest_class(class_label(index(nearest_idx))) + (weight_num + 1 - nearest_idx) * weight_mat(real_x, real_y);
        end
%         nearest_idx(test_file_idx, local_block_idx, 1) = index(1);
%         nearest_idx(test_file_idx, local_block_idx, 2) = index(2);
%         nearest_idx(test_file_idx, local_block_idx, 3) = index(3);
    end
    
%    [min_dis(test_file_idx), min_idx(test_file_idx)] = max(nearest_block);
     [min_dis(test_file_idx), min_idx(test_file_idx)] = max(nearest_class);
end

% a map from facial expression to label;
label_map = cell(7, 1);
label_map{1} = 'AN';
label_map{2} = 'DI';
label_map{3} = 'FE';
label_map{4} = 'HA';
label_map{5} = 'SA';
label_map{6} = 'SU';
label_map{7} = 'NE';

% calculate the accuracy
accuracy = 0;
for test_file_idx = 1 : test_file_num
    real_expression = test_file_name(test_file_idx).name(4 : 5);
    %test_expression = label_map{(class_label(min_idx(test_file_idx)))};
     test_expression = label_map{min_idx(test_file_idx)};
    fprintf('real expression: %s, test expression: %s, minnimum distance %f\n', real_expression, test_expression, min_dis(test_file_idx));
    if (strcmp(real_expression, test_expression))
        accuracy = accuracy + 1;
    end
end
accuracy = accuracy / test_file_num;


res_one_inc = 1;
res_two_inc = 1;
% highest_accur = 0;
% 
% for two_inc = 1 : 0.1 : 10
%     for one_inc = two_inc : 0.1 : 10
%         for test_file_idx = 1 : test_file_num
%             nearest_block = zeros(train_vec_num, 1);
%             for local_block_idx = 1 : 3 * block_num
%                 nearest_block(nearest_idx(test_file_idx, local_block_idx, 1)) = nearest_block(nearest_idx(test_file_idx, local_block_idx, 1)) + one_inc;
%                 nearest_block(nearest_idx(test_file_idx, local_block_idx, 2)) = nearest_block(nearest_idx(test_file_idx, local_block_idx, 2)) + two_inc;
%                 nearest_block(nearest_idx(test_file_idx, local_block_idx, 3)) = nearest_block(nearest_idx(test_file_idx, local_block_idx, 3)) + 1;
%             end
%             [min_dis(test_file_idx), min_idx(test_file_idx)] = max(nearest_block);
%         end
%         
%         accuracy = 0;    
%         for test_file_idx = 1 : test_file_num
%             real_expression = test_file_name(test_file_idx).name(4 : 5);
%             test_expression = label_map{(class_label(min_idx(test_file_idx)))};
%             % test_expression = label_map{min_idx(test_file_idx)};
%             fprintf('real expression: %s, test expression: %s, minnimum distance %f\n', real_expression, test_expression, min_dis(test_file_idx));
%             if (strcmp(real_expression, test_expression))
%                 accuracy = accuracy + 1;
%             end
%         end
%         accuracy = accuracy / test_file_num;
%         
%         if (highest_accur < accuracy)
%             highest_accur = accuracy;
%             res_one_inc = one_inc;
%             res_two_inc = two_inc;
%         end
%     end
% end
% 
% accuracy = highest_accur;