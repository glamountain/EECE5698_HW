function [est_r_ea_e,est_clock] = GNSS_WLSA_position(...
    GNSS_measurements,no_GNSS_meas,predicted_r_ea_e,Q0,W)
% GNSS_WLSA_position - Calculates position, clock offset, 
% using weighted iterated least squares with a prioris.
%
% Software for use with "Principles of GNSS, Inertial, and Multisensor
% Integrated Navigation Systems," Second Edition.
%
% This function created 11/4/2012 by Paul Groves
%
% Inputs:
%   GNSS_measurements     GNSS measurement data:
%     Column 1              Pseudo-range measurements (m)
%     Column 2              Pseudo-range rate measurements (m/s)
%     Columns 3-5           Satellite ECEF position (m)
%     Columns 6-8           Satellite ECEF velocity (m/s)
%   no_GNSS_meas          Number of satellites for which measurements are
%                         supplied
%   predicted_r_ea_e      prior predicted ECEF user position (m)
%   W                     Weighting matrix
%   Q0                    Uncertainty on initial position
%
% Outputs:
%   est_r_ea_e            estimated ECEF user position (m)
%   est_clock             estimated receiver clock offset (m) and drift (m/s)
 
% Copyright 2012, Paul Groves
% License: BSD; see license.txt for details
%
%   P. Closas (2018): version only for position and clock offset WLSA estimation
% 

% Constants (sone of these could be changed to inputs at a later date)
c = 299792458; % Speed of light in m/s
omega_ie = 7.292115E-5;  % Earth rotation rate in rad/s

% Begins

% POSITION AND CLOCK OFFSET

% Setup predicted state
x_pred(1:3,1) = predicted_r_ea_e;
x_pred(4,1) = 0;
test_convergence = 1;

% initialize
pred_meas = zeros(no_GNSS_meas,1);
H_matrix = zeros(no_GNSS_meas,4);
num_iter = 0;

% Repeat until convergence (i.e. two consecutive iterations provide almost identical results)
while test_convergence>0.0001
    
    % number of iteration
    num_iter = num_iter + 1;
    
    % Loop measurements
    for j = 1:no_GNSS_meas

        % Predict approx range 
        delta_r = GNSS_measurements(j,3:5)' - x_pred(1:3);
        approx_range = sqrt(delta_r' * delta_r);

        % Calculate frame rotation during signal transit time using (8.36)
        C_e_I = [1, omega_ie * approx_range / c, 0;...
                 -omega_ie * approx_range / c, 1, 0;...
                 0, 0, 1];

        % Predict pseudo-range using (9.143)
        delta_r = C_e_I *  GNSS_measurements(j,3:5)' - x_pred(1:3);
        range = sqrt(delta_r' * delta_r);
        pred_meas(j,1) = range + x_pred(4);
        
        % Predict line of sight and deploy in measurement matrix, (9.144)
        H_matrix (j,1:3) = - delta_r' / range;
        H_matrix (j,4) = 1;
        
    end % for j
        
    % Weighted least-squares with a prioris solution
    K = Q0*H_matrix(1:no_GNSS_meas,:)'*inv(H_matrix(1:no_GNSS_meas,:)*Q0*H_matrix(1:no_GNSS_meas,:)' + inv(W));

    x_est = x_pred + K *...
        (GNSS_measurements(1:no_GNSS_meas,1) -  pred_meas(1:no_GNSS_meas));

    % Test convergence    
    test_convergence = sqrt((x_est - x_pred)' * (x_est - x_pred));
    
    % Set predictions to estimates for next iteration
    x_pred = x_est;
    
end % while

num_iter;

% Set outputs to estimates
est_r_ea_e(1:3,1) = x_est(1:3);
est_clock(1) = x_est(4);

