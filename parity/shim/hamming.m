function w = hamming(n)
% Stand-in for the Signal Processing Toolbox hamming(), which is not
% installed on this machine. Implements MATLAB's documented symmetric
% Hamming window:
%
%   w(k) = 0.54 - 0.46*cos(2*pi*k/(n-1)),  k = 0 .. n-1
%
% This is the only piece of the parity harness that is not the project's
% own code. Everything else calls Part1 / MRSI.jl directly.
if n == 1
    w = 1;
    return
end
k = (0:n-1)';
w = 0.54 - 0.46*cos(2*pi*k/(n-1));
end
