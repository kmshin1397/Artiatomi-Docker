% Example script to set up for iterative local refinement on a set of 
% tomograms. With the artiatomi-tools Docker image, the executables should
% all be on the PATH variable and the locations shouldn't need to be more
% than just the executable name for it to work (instead of the full paths
% seen below).

% Prep files necessary for refinement

main_root = '/data/kshin/T4SS_sim/PDB/c4/IMOD/Artia/refine';
mkdir(main_root);
mkdir(sprintf('%s/motls', main_root));
%% Split latest motivelist into motivelists for each tomogram
motl = artia.em.read(...
    '/data/kshin/T4SS_sim/PDB/c4/IMOD/Artia/motls/motl_2.em');

tomonr = cell2mat(readcell("/data/kshin/T4SS_sim/PDB/c4/IMOD/Artia/tomonums.txt", 'Delimiter', ' '));

for i = 1:numel(tomonr)
    idx = motl(5,:)==tomonr(i);
    tomo_motl = motl(:,idx);
    
    % Write out the individual motivelists
    artia.em.write(tomo_motl, ...
        sprintf('/data/kshin/T4SS_sim/PDB/c4/IMOD/Artia/refine/motls/%d_ref_motl.em', ...
            tomonr(i)));
end

%% Create a refinement reference by overlaying the mask and the latest ref
% Load mask and latest reference
ref = artia.em.read('/data/kshin/T4SS_sim/PDB/c4/IMOD/Artia/ref/ref2.em');
mask = artia.em.read('/data/kshin/T4SS_sim/PDB/c4/IMOD/Artia/other/mask.em');
% Overlay them
ref_mask = (ref .* mask);
avg_ref_mask = mean(ref_mask(:));
std_ref_mask = std(ref_mask(:));

ref_refinement = (ref_mask - avg_ref_mask) ./ std_ref_mask;
artia.em.write(ref_refinement, '/data/kshin/T4SS_sim/PDB/c4/IMOD/Artia/refine/ref_refinement.em');

%% Set up general options 
opts = struct();

% General options
opts.iters = 3; % Iters per tomogram
opts.nodes = 1;

% Executable locations and remote setup
opts.cAligner = '/home/kshin/Documents/repositories/cAligner/build/cAligner';
opts.EmSART = '/home/kshin/Documents/repositories/Artiatomi/build/EmSART';
opts.EmSARTRefine = '/home/kshin/Documents/repositories/Artiatomi/build/EmSARTRefine';
opts.STA = 'SubTomogramAverageMPI';
opts.STA_dir = '/home/kshin/Documents/repositories/Artiatomi/build';
opts.remote = true;
opts.host = 'Artiatomi@localhost';
opts.port = 'port number';

% Reconstruction parameters
opts.reconDim = [1000 1000 300]; %typical 1k size
opts.imDim = [2000 2000]; % 2k image stack
opts.volumeShifts = [0 0 0];
opts.maAmount = 1;
opts.maAngle = 0;
opts.voxelSize = 2;

% Averaging parameters
opts.boxSize = 64;
opts.wedge = artia.em.read('/data/kshin/T4SS_sim/PDB/c4/IMOD/Artia/other/wedge.em');
opts.mask = artia.em.read('/data/kshin/T4SS_sim/PDB/c4/IMOD/Artia/other/mask.em');
opts.reference = artia.em.read('/data/kshin/T4SS_sim/PDB/c4/IMOD/Artia/refine/ref_refinement.em'); 
opts.maskCC = artia.em.read('/data/kshin/T4SS_sim/PDB/c4/IMOD/Artia/other/maskCC_small.em');
opts.angIter = 10;
opts.angIncr = 0.1;
opts.phiAngIter = 10;
opts.phiAngIncr = 0.1;
opts.avgLowPass = 12;
opts.avgHighPass = 0;
opts.avgSigma = 3;

% Refinement (projection matching) parameters
opts.groupMode = 'MaxDistance';
opts.maxDistance = 150;
opts.groupSize = 20;
opts.maxShift = 15;
opts.speedUpDist = 60;

% Refinement band pass filter
opts.lowPass = 200;
opts.lowPassSigma = 50;
opts.highPass = 20;
opts.highPassSigma = 10;

% Volume size computation
opts.borderSize = 5*opts.boxSize;

%% Set tomogram-specific options and run
% For some reason this may randomly freeze/not work for some tomograms so
% it is probably a good idea to periodically check in and restart this
% section from a later index i (by changing that 1 in 1:numel(tomonr)) to
% skip problematic tomograms.
for i = 1:numel(tomonr)
    
    tomoNum = tomonr(i);
    % minus 1 for the tomogram number because we 1-indexed the tomonr array
    opts.projFile = sprintf('/data/kshin/T4SS_sim/PDB/c4/IMOD/T4SS_%d/T4SS_%d.st', tomoNum - 1, tomoNum - 1);
    opts.markerFile = sprintf('/data/kshin/T4SS_sim/PDB/c4/IMOD/T4SS_%d/T4SS_%d_markers.em', tomoNum - 1, tomoNum -1);
    opts.projDir = sprintf('/data/kshin/T4SS_sim/PDB/c4/IMOD/Artia/refine/tomo_%d', tomoNum);
    opts.tomoNr = tomoNum;
    opts.motl = artia.em.read(sprintf('/data/kshin/T4SS_sim/PDB/c4/IMOD/Artia/refine/motls/%d_ref_motl.em', tomoNum));
    
    % RUN!
    refineAlign.iterative_alignment(opts)
    
end
