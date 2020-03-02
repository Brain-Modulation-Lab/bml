function bml_atlas2labeling(atlasname, spacefile)
% adpated from ea_atlas2labeling to work for Distal atlas

if ~exist('spacefile','var')
    spacefile = [ea_space,'t2.nii'];
end

copyfile([ea_space([],'atlases'),atlasname], [ea_space([],'atlases'),atlasname,'_copy']);
copybase = [ea_space([],'atlases'), atlasname, '_copy', filesep];

hdr = ea_fslhd(spacefile);
volnum = length(ea_regexpdir([copybase, 'lh'], '.*\.nii(\.gz)?$', 0)) + ...
         length(ea_regexpdir([copybase, 'rh'], '.*\.nii(\.gz)?$', 0)) + ...
         length(ea_regexpdir([copybase, 'mixed'], '.*\.nii(\.gz)?$', 0)) + ...
         length(ea_regexpdir([copybase, 'midline'], '.*\.nii(\.gz)?$', 0));
Astr = cell(volnum + 1, 1);
Fvol = zeros(hdr.dim1, hdr.dim2, hdr.dim3);
Maxvol = zeros(hdr.dim1, hdr.dim2, hdr.dim3);

subfs = {'lh', 'rh', 'mixed', 'midline'};

Astr{1} = 'None';
cnt = 1;
for subf=1:length(subfs)
    subbase = [copybase, subfs{subf}, filesep];
    switch subfs{subf}
        case 'lh'
            append = '_L';
        case 'rh'
            append = '_R';
        otherwise
            append = '';
    end

    gzfiles = ea_regexpdir(subbase, '.*\.nii\.gz$', 0);
    if ~isempty(gzfiles)
        gunzip(gzfiles);
        ea_delete(gzfiles);
    end

    niifiles = ea_regexpdir(subbase, '.*\.nii$', 0);
    for i=1:length(niifiles)
        disp(['Reslicing structures ', num2str(i,'%02d'), '/', num2str(length(niifiles),'%02d'), '...']);
        %ea_conformspaceto(spacefile, niifiles{i}, 1);
        ea_conformspaceto(spacefile, niifiles{i}, 1, 0, [], 0);
    end

    for i=1:length(niifiles)
        disp(['Stacking structures ', num2str(i,'%02d'), '/', num2str(length(niifiles),'%02d'), '...']);
        [~, nuclname] = fileparts(niifiles{i});
        Astr{cnt+1} = [nuclname, append];
        nii = ea_load_nii(niifiles{i});
        nii.img(isnan(nii.img)) = 0;
        nii.img(nii.img<0.5) = 0;
        [Maxvol, Idxvol] = max(cat(4,Maxvol,nii.img),[],4);
        Fvol(Idxvol==2)=cnt;
        cnt = cnt+1;
    end
end

disp('Write out NIfTI..');
lab = [];
lab.fname = [ea_space([],'labeling'), atlasname, '.nii'];
lab.mat = ea_get_affine(spacefile);
lab.dim = [hdr.dim1, hdr.dim2, hdr.dim3];
lab.pinfo = [1; 0];
lab.descrip = [atlasname ' labeling'];
if max(Fvol,[],'all') <= 255
    lab.dt = [spm_type('uint8') spm_platform('bigend')];
else
	lab.dt = [spm_type('uint16') spm_platform('bigend')];   
end
spm_write_vol(lab, Fvol);

disp('Write out TXT..');
f = fopen([ea_space([],'labeling'), atlasname, '.txt'], 'w');
for nucl=1:length(Astr)
    fprintf(f,'%d %s\n', nucl - 1, Astr{nucl});
end
fclose(f);

rmdir([ea_space([],'atlases'), atlasname, '_copy'], 's')

disp('Done!');
