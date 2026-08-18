% MATLAB half of the Julia/MATLAB parity harness.
% Calls Part1's own HammingFilter and op_CoilCombineData on the shared inputs
% and writes the results back in the same flat Float64 layout.

here   = fileparts(mfilename('fullpath'));
io_dir = fullfile(here, 'io');

% Point PART1_DIR at a Part1 checkout, or at /opt/Part1 inside the container.
part1 = getenv('PART1_DIR');
if isempty(part1)
    part1 = fullfile(fileparts(fileparts(here)), 'Part1_Reco_LCModel_MUSICAL_Streamlined_Git');
end
if ~isfolder(part1)
    error('Part1 checkout not found at "%s". Set PART1_DIR.', part1);
end

addpath(fullfile(here, 'shim'));                                  % hamming() stand-in
addpath(genpath(fullfile(part1, 'MatlabFunctions', 'MRSIMatlabFunctions')));

csi_odd  = read_complex(io_dir, 'csi_odd.bin');
csi_even = read_complex(io_dir, 'csi_even.bin');
ref      = read_complex(io_dir, 'ref.bin');

% --- T1: the raw window values -------------------------------------------
for n = [8 21 31]
    write_complex(io_dir, sprintf('m_window_%d.bin', n), complex(hamming(n)));
end

% --- T2: z-Hamming exactly as MRSI_Reconstruction.m:674 calls it ----------
write_complex(io_dir, 'm_hammz_odd.bin',  HammingFilter(csi_odd,  [3], 100, 'OuterProduct', 0));
write_complex(io_dir, 'm_hammz_even.bin', HammingFilter(csi_even, [3], 100, 'OuterProduct', 0));

% --- T3: the FFT convention used around the filter ------------------------
tmp = ifftshift(csi_odd, 3); tmp = fft(tmp, [], 3); tmp = fftshift(tmp, 3);
write_complex(io_dir, 'm_fftz_odd.bin', tmp);

% --- T4: MUSICAL coil combination via Part1's own function ----------------
% weights = conj of the first point of the reference scan, as at line 968.
% DataSize is indexed at [4 6] inside op_CoilCombineData, so it must carry a
% 6th (repetition) entry even though these arrays are 5-D.
csi = struct();
csi.Data                 = csi_odd;
csi.Par.DataSize         = [size(csi_odd) 1];
csi.RecoPar              = csi.Par;

weights = struct();
weights.Data             = conj(ref(:,:,:,1,:));
weights.Par.DataSize     = [size(weights.Data) 1];
weights.RecoPar          = weights.Par;

ok = true;
try
    out = op_CoilCombineData(csi, weights);
    combined = out.Data * 1e5;                 % the *10^5 rescale at line 1005
catch err
    ok = false;
    fprintf('op_CoilCombineData failed: %s\n', err.message);
end
if ok
    write_complex(io_dir, 'm_coilcomb_odd.bin', combined);
    fprintf('coilcomb: real function OK\n');
else
    fprintf('coilcomb: SKIPPED\n');
end

% --- T5: the reference-point fallback at MRSI_Reconstruction.m:568-572 ----
% With 3 or fewer FID points MATLAB takes point 1, not point 4.
ref3 = read_complex(io_dir, 'ref3.bin');
if size(ref3, 4) > 3
    pt3 = ref3(:,:,:,4,:);
else
    pt3 = ref3(:,:,:,1,:);
end

csi3 = struct();
csi3.Data            = csi_odd;
csi3.Par.DataSize    = [size(csi_odd) 1];
csi3.RecoPar         = csi3.Par;

w3 = struct();
w3.Data              = conj(pt3);
w3.Par.DataSize      = [size(w3.Data) 1];
w3.RecoPar           = w3.Par;

out3 = op_CoilCombineData(csi3, w3);
write_complex(io_dir, 'm_coilcomb_ref3.bin', out3.Data * 1e5);
fprintf('coilcomb ref3: OK\n');

fprintf('MATLAB side done\n');


function a = read_complex(io_dir, name)
    dims = load(fullfile(io_dir, [name '.size']), '-ascii');
    fid  = fopen(fullfile(io_dir, name), 'r');
    raw  = fread(fid, Inf, 'double');
    fclose(fid);
    n    = numel(raw)/2;
    a    = reshape(complex(raw(1:n), raw(n+1:end)), dims(:)');
end

function write_complex(io_dir, name, a)
    fid = fopen(fullfile(io_dir, name), 'w');
    fwrite(fid, real(a(:)), 'double');
    fwrite(fid, imag(a(:)), 'double');
    fclose(fid);
    f2 = fopen(fullfile(io_dir, [name '.size']), 'w');
    fprintf(f2, '%s\n', num2str(size(a)));
    fclose(f2);
end
