#!/usr/bin/octave -qf

arg_list = argv();
filename = arg_list{1}; % input filename (.e)
out_filename = arg_list{2}; % output prefix
%%
addpath('NicoletFile_e2edf/');
try
  obj = NicoletFile(filename);
  hospital_id = obj.patientInfo.altID;
  birth_date = obj.patientInfo.DOB; %% date of birth
  samplingRate = obj.segments(1).samplingRate(1);
  record_date = obj.segments(1).startDate;
  sprintf('%d-%d-%d',record_date(1),record_date(2),record_date(3))
  % find sensor with obj.tsInfo.dSamplingRate == samplingRate
  use_sensor_idx = zeros(length(obj.tsInfo),1);
  for i = 1:length(use_sensor_idx)
   use_sensor_idx(i) = obj.tsInfo(i).dSamplingRate == samplingRate;
  end
  use_sensor = find(use_sensor_idx);
  sensor_info = {};
  for i = 1:length(use_sensor)
   sensor_info(i) = cellstr(obj.tsInfo(i).activeSensor);
  end
  total_segments = length(obj.segments);
  % get combined data %
  final_data = [];
  for i = 1:total_segments
   d1=obj.segments(i).duration*samplingRate;
   ori_data=getdataQ(obj,i,[1 d1],use_sensor); %% duration * samplingRate; 
   final_data = [final_data;ori_data];
  end
  write_edf(sprintf('%s.edf',out_filename),sensor_info,samplingRate,final_data)
catch exception
 'error' 
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

