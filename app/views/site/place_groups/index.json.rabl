collection @place_groups

attributes :title, :permalink, :logo

node(:logo) { |pg| pg.logo.url(:main) }
node(:resto_count) { |pg| pg.resto_count(current_city) }
node(:landing_link) { |pg| pg.landing_link(current_city) }
