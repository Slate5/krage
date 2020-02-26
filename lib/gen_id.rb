# frozen_string_literal: true
ids_ar = ['1c1d6752-8d60-46c1-8e22-06566a269a01',
          '25f16397-5503-41b1-aa6c-3b2d8d7e6737',
          'ea2ace5b-35e8-4726-a20e-640d18dc8190',
          'fc11c7c4-9289-4f24-9b81-b0af5ad7e88d',
          '77059d1c-e775-4168-855b-ec4f62850171',
          'e8145d31-b81d-4b6c-bd2a-d30e10da3ab9',
          '3ca61467-9414-4b16-81f2-6b72a1987b86',
          'a407653d-d154-46a7-924f-2e8c5aa77fa9']

current_ids = []
profile = File.read("#{File.dirname(__dir__)}/ext/.user_profile.dconf")
profile.gsub(/(\w+-){4}\w+/) { |m| current_ids << m }
current_ids.uniq!

profile_id = nil
ids_ar.each do |id1|
  current_ids.each_with_index do |id2,idx|
    if id1 == id2
      break
    elsif (idx+1) == current_ids.length
      profile_id = id1
    end
  end
  break if profile_id
end

profile_id ||= ids_ar[0]

print profile_id
